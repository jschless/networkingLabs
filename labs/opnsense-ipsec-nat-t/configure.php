<?php

/*
 * Canonical OPNsense 26.1 configuration for the disposable NAT-T lab.
 *
 * This file is streamed to php(1) over loopback-only SSH by solution.sh. The
 * credential below is deliberately non-production and valid only inside the
 * throwaway lab overlays. Never reuse it outside this range.
 */

require_once("config.inc");

use OPNsense\Core\Config;
use OPNsense\Firewall\Filter as FirewallFilter;
use OPNsense\IPsec\IPsec;
use OPNsense\IPsec\Swanctl;
use OPNsense\Routing\Gateways;

$role = getenv("NATT_ROLE");
$phase = getenv("NATT_PHASE");
if (!in_array($role, ["hq", "branch"], true)
    || !in_array($phase, ["base", "firewall"], true)) {
    fwrite(STDERR, "invalid lab configurator role or phase\n");
    exit(64);
}

$isHq = $role === "hq";
$roleIndex = $isHq ? "1" : "2";
$wanIp = $isHq ? "198.51.100.2" : "10.200.0.2";
$wanGateway = $isHq ? "198.51.100.1" : "10.200.0.1";
$lanIp = $isHq ? "10.10.1.1" : "10.20.1.1";
$lanDescription = $isHq ? "HQ_LAN" : "BRANCH_LAN";
$localId = $isHq ? "hq.lab" : "branch.lab";
$remoteId = $isHq ? "branch.lab" : "hq.lab";
$localTs = $isHq ? "10.10.1.0/24" : "10.20.1.0/24";
$remoteTs = $isHq ? "10.20.1.0/24" : "10.10.1.0/24";
$remoteAddr = $isHq ? "" : "198.51.100.2";
$gatewayName = $isHq ? "NATT_HQ_GW" : "NATT_BRANCH_GW";
$description = $isHq ? "NAT-T lab HQ" : "NAT-T lab Branch";

$uuids = [
    "gateway" => "a1000000-0000-4000-8000-00000000000{$roleIndex}",
    "connection" => "a2000000-0000-4000-8000-00000000000{$roleIndex}",
    "local" => "a3000000-0000-4000-8000-00000000000{$roleIndex}",
    "remote" => "a4000000-0000-4000-8000-00000000000{$roleIndex}",
    "child" => "a5000000-0000-4000-8000-00000000000{$roleIndex}",
    "psk" => "a6000000-0000-4000-8000-00000000000{$roleIndex}",
    "firewall" => "a7000000-0000-4000-8000-00000000000{$roleIndex}",
];

$config = Config::getInstance();
$config->lock();

if ($phase === "firewall") {
    $firewall = new FirewallFilter();
    foreach ($firewall->rules->rule->iterateItems() as $uuid => $node) {
        if ($uuid === $uuids["firewall"]
            || (string)$node->interface === "enc0"
            || str_starts_with((string)$node->description, "NAT-T lab")) {
            $firewall->rules->rule->del($uuid);
        }
    }

    $ipsecRule = $firewall->rules->rule->Add($uuids["firewall"]);
    $ipsecRule->setNodes([
        "enabled" => "1",
        "statetype" => "keep",
        "sequence" => "100",
        "action" => "pass",
        "quick" => "1",
        "interfacenot" => "0",
        "interface" => "enc0",
        "direction" => "in",
        "ipprotocol" => "inet",
        "protocol" => "any",
        "source_net" => $remoteTs,
        "source_not" => "0",
        "destination_net" => $localTs,
        "destination_not" => "0",
        "description" => "NAT-T lab allow protected peer subnet",
    ]);
    $firewall->serializeToConfig();
    $config->save();
    echo "configured {$role} firewall phase\n";
    exit(0);
}

$xml = $config->object();

/* Keep the prepared vtnet0 management interface; replace data-NIC ownership. */
$removeInterfaces = [];
foreach ($xml->interfaces->children() as $name => $interface) {
    $device = (string)$interface->if;
    if ($name === "opt1" || $name === "opt2"
        || in_array($device, ["vtnet1", "vtnet2"], true)) {
        $removeInterfaces[(string)$name] = true;
    }
}
foreach (array_keys($removeInterfaces) as $name) {
    unset($xml->interfaces->{$name});
}

$wan = $xml->interfaces->addChild("opt1");
$wan->addChild("enable", "1");
$wan->addChild("descr", "WAN_DATA");
$wan->addChild("if", "vtnet1");
$wan->addChild("ipaddr", $wanIp);
$wan->addChild("subnet", "24");
$wan->addChild("gateway", $gatewayName);

$lan = $xml->interfaces->addChild("opt2");
$lan->addChild("enable", "1");
$lan->addChild("descr", $lanDescription);
$lan->addChild("if", "vtnet2");
$lan->addChild("ipaddr", $lanIp);
$lan->addChild("subnet", "24");

$gateways = new Gateways();
foreach ($gateways->gateway_item->iterateItems() as $uuid => $node) {
    if ($uuid === $uuids["gateway"]
        || (string)$node->interface === "opt1"
        || str_starts_with((string)$node->name, "NATT_")) {
        $gateways->gateway_item->del($uuid);
    }
}
$gateway = $gateways->gateway_item->Add($uuids["gateway"]);
$gateway->setNodes([
    "disabled" => "0",
    "name" => $gatewayName,
    "descr" => "{$description} underlay",
    "interface" => "opt1",
    "ipprotocol" => "inet",
    "gateway" => $wanGateway,
    "defaultgw" => "1",
    "monitor_disable" => "1",
    "priority" => "255",
    "weight" => "1",
]);
$gateways->serializeToConfig();

if (!isset($xml->filter)) {
    $xml->addChild("filter");
}
for ($index = count($xml->filter->rule) - 1; $index >= 0; --$index) {
    $rule = $xml->filter->rule[$index];
    $interfaces = preg_split('/,/', (string)$rule->interface);
    if (str_starts_with((string)$rule->descr, "NAT-T lab")
        || in_array("opt1", $interfaces, true)
        || in_array("opt2", $interfaces, true)) {
        unset($xml->filter->rule[$index]);
    }
}

function addPassRule($filter, $description, $interface, $source, $destination, $protocol = null, $port = null)
{
    $rule = $filter->addChild("rule");
    $rule->addChild("type", "pass");
    $rule->addChild("ipprotocol", "inet");
    $rule->addChild("descr", $description);
    $rule->addChild("interface", $interface);
    if ($protocol !== null) {
        $rule->addChild("protocol", $protocol);
    }
    $sourceNode = $rule->addChild("source");
    if ($source === "any") {
        $sourceNode->addChild("any");
    } else {
        $sourceNode->addChild("network", $source);
    }
    $destinationNode = $rule->addChild("destination");
    if ($destination === "any") {
        $destinationNode->addChild("any");
    } else {
        $destinationNode->addChild("network", $destination);
    }
    if ($port !== null) {
        $destinationNode->addChild("port", (string)$port);
    }
}

addPassRule($xml->filter, "NAT-T lab allow LAN", "opt2", "opt2", "any");
if ($isHq) {
    addPassRule($xml->filter, "NAT-T lab allow IKE", "opt1", "any", "opt1", "udp", 500);
    addPassRule($xml->filter, "NAT-T lab allow NAT-T", "opt1", "any", "opt1", "udp", 4500);
    addPassRule($xml->filter, "NAT-T lab allow underlay probe", "opt1", "any", "opt1", "icmp");
}

/* The complete Swanctl subtree is learner-owned in this throwaway overlay. */
$swanctl = new Swanctl();
foreach (["Connections.Connection", "locals.local", "remotes.remote", "children.child"] as $reference) {
    $container = $swanctl->getNodeByReference($reference);
    foreach ($container->iterateItems() as $uuid => $node) {
        $container->del($uuid);
    }
}

$connection = $swanctl->Connections->Connection->Add($uuids["connection"]);
$connection->setNodes([
    "enabled" => "1",
    "proposals" => "aes256-sha256-modp2048",
    "unique" => "replace",
    "version" => "2",
    "mobike" => "0",
    "local_addrs" => $wanIp,
    "remote_addrs" => $remoteAddr,
    "encap" => "0",
    "dpd_delay" => "30",
    "description" => "natt-site-to-site",
]);

$local = $swanctl->locals->local->Add($uuids["local"]);
$local->setNodes([
    "enabled" => "1",
    "connection" => $uuids["connection"],
    "round" => "0",
    "auth" => "psk",
    "id" => $localId,
    "description" => "{$description} local PSK",
]);

$remote = $swanctl->remotes->remote->Add($uuids["remote"]);
$remote->setNodes([
    "enabled" => "1",
    "connection" => $uuids["connection"],
    "round" => "0",
    "auth" => "psk",
    "id" => $remoteId,
    "description" => "{$description} remote PSK",
]);

$child = $swanctl->children->child->Add($uuids["child"]);
$child->setNodes([
    "enabled" => "1",
    "connection" => $uuids["connection"],
    "mode" => "tunnel",
    "policies" => "1",
    "start_action" => $isHq ? "trap" : "start",
    "close_action" => "none",
    "dpd_action" => $isHq ? "trap" : "start",
    "esp_proposals" => "aes256-sha256-modp2048",
    "local_ts" => $localTs,
    "remote_ts" => $remoteTs,
    "description" => "natt-protected-lans",
]);
$swanctl->serializeToConfig();

$ipsec = new IPsec();
$ipsec->general->enabled = "1";
foreach ($ipsec->preSharedKeys->preSharedKey->iterateItems() as $uuid => $node) {
    $ipsec->preSharedKeys->preSharedKey->del($uuid);
}
$psk = $ipsec->preSharedKeys->preSharedKey->Add($uuids["psk"]);
$psk->setNodes([
    "ident" => $localId,
    "remote_ident" => $remoteId,
    "keyType" => "PSK",
    "Key" => "NattLab-PSK-2026!",
    "description" => "{$description} disposable PSK",
]);
$ipsec->serializeToConfig();

if (!isset($xml->ipsec)) {
    $xml->addChild("ipsec");
}
$xml->ipsec->enable = "1";
$config->save();
echo "configured {$role} base phase\n";
