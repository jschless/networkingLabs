<?php

/* Read-only, secret-safe saved-state grader streamed over loopback SSH. */

require_once("config.inc");

use OPNsense\Core\Config;
use OPNsense\Firewall\Filter as FirewallFilter;
use OPNsense\IPsec\IPsec;
use OPNsense\IPsec\Swanctl;
use OPNsense\Routing\Gateways;

$role = getenv("NATT_ROLE");
if (!in_array($role, ["hq", "branch"], true)) {
    exit(64);
}

$isHq = $role === "hq";
$roleIndex = $isHq ? "1" : "2";
$wanIp = $isHq ? "198.51.100.2" : "10.200.0.2";
$wanGateway = $isHq ? "198.51.100.1" : "10.200.0.1";
$lanIp = $isHq ? "10.10.1.1" : "10.20.1.1";
$localId = $isHq ? "hq.lab" : "branch.lab";
$remoteId = $isHq ? "branch.lab" : "hq.lab";
$localTs = $isHq ? "10.10.1.0/24" : "10.20.1.0/24";
$remoteTs = $isHq ? "10.20.1.0/24" : "10.10.1.0/24";
$remoteAddr = $isHq ? "" : "198.51.100.2";
$gatewayName = $isHq ? "NATT_HQ_GW" : "NATT_BRANCH_GW";
$lanDescription = $isHq ? "HQ_LAN" : "BRANCH_LAN";
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

function emitResult($name, $result)
{
    echo $name . "=" . ($result ? "1" : "0") . "\n";
}

function nodeMatches($node, $expected)
{
    foreach ($expected as $name => $value) {
        if ((string)$node->{$name} !== (string)$value) {
            return false;
        }
    }
    return true;
}

function singletonMatches($container, $uuid, $expected)
{
    $items = [];
    foreach ($container->iterateItems() as $itemUuid => $node) {
        $items[$itemUuid] = $node;
    }
    return count($items) === 1
        && isset($items[$uuid])
        && nodeMatches($items[$uuid], $expected);
}

function endpointValue($node)
{
    if (isset($node->any)) {
        return "any";
    }
    if (isset($node->network)) {
        return "network:" . (string)$node->network;
    }
    return "invalid";
}

$config = Config::getInstance();
$xml = $config->object();

$opt1 = isset($xml->interfaces->opt1) ? $xml->interfaces->opt1 : null;
$opt2 = isset($xml->interfaces->opt2) ? $xml->interfaces->opt2 : null;
$dataNicOwners = 0;
foreach ($xml->interfaces->children() as $name => $interface) {
    if (in_array((string)$interface->if, ["vtnet1", "vtnet2"], true)) {
        ++$dataNicOwners;
    }
}
emitResult("interfaces", $opt1 !== null && $opt2 !== null
    && nodeMatches($opt1, [
        "enable" => "1", "descr" => "WAN_DATA", "if" => "vtnet1",
        "ipaddr" => $wanIp, "subnet" => "24", "gateway" => $gatewayName,
    ])
    && nodeMatches($opt2, [
        "enable" => "1", "descr" => $lanDescription, "if" => "vtnet2",
        "ipaddr" => $lanIp, "subnet" => "24",
    ])
    && $dataNicOwners === 2);

$enc0Registered = false;
foreach ($xml->interfaces->children() as $name => $interface) {
    if ($name === "enc0" || (string)$interface->if === "enc0") {
        $enc0Registered = true;
    }
}
emitResult("enc0_registered", $enc0Registered);

$gateways = new Gateways();
$targetGateways = [];
foreach ($gateways->gateway_item->iterateItems() as $uuid => $node) {
    if ((string)$node->interface === "opt1" || str_starts_with((string)$node->name, "NATT_")) {
        $targetGateways[$uuid] = $node;
    }
}
emitResult("gateway", count($targetGateways) === 1
    && isset($targetGateways[$uuids["gateway"]])
    && nodeMatches($targetGateways[$uuids["gateway"]], [
        "disabled" => "0", "name" => $gatewayName,
        "descr" => "{$description} underlay", "interface" => "opt1",
        "ipprotocol" => "inet", "gateway" => $wanGateway,
        "defaultgw" => "1", "monitor_disable" => "1",
        "priority" => "255", "weight" => "1",
    ]));

$expectedRules = [
    "NAT-T lab allow LAN" => ["opt2", "", "", "network:opt2", "any"],
];
if ($isHq) {
    $expectedRules["NAT-T lab allow IKE"] = ["opt1", "udp", "500", "any", "network:opt1"];
    $expectedRules["NAT-T lab allow NAT-T"] = ["opt1", "udp", "4500", "any", "network:opt1"];
    $expectedRules["NAT-T lab allow underlay probe"] = ["opt1", "icmp", "", "any", "network:opt1"];
}
$actualRules = [];
$relevantRuleCount = 0;
if (isset($xml->filter)) {
    foreach ($xml->filter->rule as $rule) {
        $interfaces = preg_split('/,/', (string)$rule->interface);
        if (str_starts_with((string)$rule->descr, "NAT-T lab")
            || in_array("opt1", $interfaces, true)
            || in_array("opt2", $interfaces, true)) {
            ++$relevantRuleCount;
            $actualRules[(string)$rule->descr] = [
                (string)$rule->interface,
                (string)$rule->protocol,
                (string)$rule->destination->port,
                endpointValue($rule->source),
                endpointValue($rule->destination),
            ];
        }
    }
}
ksort($actualRules);
ksort($expectedRules);
emitResult("legacy_rules", $relevantRuleCount === count($expectedRules)
    && $actualRules === $expectedRules);

$swanctl = new Swanctl();
emitResult("connection", singletonMatches(
    $swanctl->Connections->Connection,
    $uuids["connection"],
    [
        "enabled" => "1", "proposals" => "aes256-sha256-modp2048",
        "unique" => "replace", "version" => "2", "mobike" => "0",
        "local_addrs" => $wanIp, "remote_addrs" => $remoteAddr,
        "encap" => "0", "dpd_delay" => "30",
        "description" => "natt-site-to-site",
    ]
));
emitResult("local_auth", singletonMatches(
    $swanctl->locals->local,
    $uuids["local"],
    [
        "enabled" => "1", "connection" => $uuids["connection"],
        "round" => "0", "auth" => "psk", "id" => $localId,
        "description" => "{$description} local PSK",
    ]
));
emitResult("remote_auth", singletonMatches(
    $swanctl->remotes->remote,
    $uuids["remote"],
    [
        "enabled" => "1", "connection" => $uuids["connection"],
        "round" => "0", "auth" => "psk", "id" => $remoteId,
        "description" => "{$description} remote PSK",
    ]
));
emitResult("child", singletonMatches(
    $swanctl->children->child,
    $uuids["child"],
    [
        "enabled" => "1", "connection" => $uuids["connection"],
        "mode" => "tunnel", "policies" => "1",
        "start_action" => $isHq ? "trap" : "start",
        "close_action" => "none", "dpd_action" => $isHq ? "trap" : "start",
        "esp_proposals" => "aes256-sha256-modp2048",
        "local_ts" => $localTs, "remote_ts" => $remoteTs,
        "description" => "natt-protected-lans",
    ]
));

$ipsec = new IPsec();
$psks = [];
foreach ($ipsec->preSharedKeys->preSharedKey->iterateItems() as $uuid => $node) {
    $psks[$uuid] = $node;
}
$pskExact = count($psks) === 1 && isset($psks[$uuids["psk"]])
    && nodeMatches($psks[$uuids["psk"]], [
        "ident" => $localId, "remote_ident" => $remoteId,
        "keyType" => "PSK", "description" => "{$description} disposable PSK",
    ])
    && hash_equals(
        "f0e5a5cc4b6e183f21e6cab394f762c480df78076651fab525cb4f6b5abe10e9",
        hash("sha256", (string)$psks[$uuids["psk"]]->Key)
    );
emitResult("psk", $pskExact);
emitResult("ipsec_enabled", (string)$ipsec->general->enabled === "1"
    && isset($xml->ipsec) && (string)$xml->ipsec->enable === "1");

$firewall = new FirewallFilter();
$encRules = [];
foreach ($firewall->rules->rule->iterateItems() as $uuid => $node) {
    if ((string)$node->interface === "enc0"
        || str_starts_with((string)$node->description, "NAT-T lab")) {
        $encRules[$uuid] = $node;
    }
}
emitResult("enc0_rule", count($encRules) === 1
    && isset($encRules[$uuids["firewall"]])
    && nodeMatches($encRules[$uuids["firewall"]], [
        "enabled" => "1", "statetype" => "keep", "sequence" => "100",
        "action" => "pass", "quick" => "1", "interfacenot" => "0",
        "interface" => "enc0", "direction" => "in", "ipprotocol" => "inet",
        "protocol" => "any", "source_net" => $remoteTs, "source_not" => "0",
        "destination_net" => $localTs, "destination_not" => "0",
        "description" => "NAT-T lab allow protected peer subnet",
    ]));
