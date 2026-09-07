<?php

/*
 * Canonical native configuration for the disposable OPNsense 26.1
 * remote-access concentrator. Public client keys enter through environment
 * variables; no client private key ever leaves its container.
 */

require_once("config.inc");

use OPNsense\Core\Config;
use OPNsense\Firewall\Filter as FirewallFilter;
use OPNsense\Wireguard\Client;
use OPNsense\Wireguard\General;
use OPNsense\Wireguard\Server;

$phase = getenv("RA_PHASE");
$developerPublic = getenv("RA_DEV_PUBLIC");
$contractorPublic = getenv("RA_CONTRACTOR_PUBLIC");
$validPhases = ["base", "server", "firewall", "fault", "repair", "revoke", "reenroll"];
if (!in_array($phase, $validPhases, true)
    || !preg_match('/^[A-Za-z0-9+\/]{43}=$/', $developerPublic)
    || !preg_match('/^[A-Za-z0-9+\/]{43}=$/', $contractorPublic)
    || hash_equals($developerPublic, $contractorPublic)) {
    fwrite(STDERR, "invalid lab configurator input\n");
    exit(64);
}

$uuids = [
    "server" => "b1000000-0000-4000-8000-000000000001",
    "developer" => "b2000000-0000-4000-8000-000000000001",
    "contractor" => "b2000000-0000-4000-8000-000000000002",
    "management" => "b3000000-0000-4000-8000-000000000001",
    "dev_app" => "b3000000-0000-4000-8000-000000000002",
    "dev_jump" => "b3000000-0000-4000-8000-000000000003",
    "contractor_jump" => "b3000000-0000-4000-8000-000000000004",
    "contractor_app" => "b3000000-0000-4000-8000-000000000005",
];

function derivePublicKey($privateKey)
{
    $spec = [
        0 => ["pipe", "r"],
        1 => ["pipe", "w"],
        2 => ["pipe", "w"],
    ];
    $process = proc_open(["/usr/bin/wg", "pubkey"], $spec, $pipes);
    if (!is_resource($process)) {
        return "";
    }
    fwrite($pipes[0], $privateKey . "\n");
    fclose($pipes[0]);
    $publicKey = trim(stream_get_contents($pipes[1]));
    fclose($pipes[1]);
    stream_get_contents($pipes[2]);
    fclose($pipes[2]);
    return proc_close($process) === 0 ? $publicKey : "";
}

function generatePrivateKey()
{
    $output = [];
    $status = 1;
    exec('/usr/bin/wg genkey', $output, $status);
    $privateKey = $status === 0 && count($output) === 1 ? trim($output[0]) : "";
    if (!preg_match('/^[A-Za-z0-9+\/]{43}=$/', $privateKey)) {
        fwrite(STDERR, "could not create concentrator identity\n");
        exit(1);
    }
    return $privateKey;
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

function exactClients($clientModel, $uuids, $developerPublic, $contractorPublic, $allowedAddresses, $contractorEnabled)
{
    $items = [];
    foreach ($clientModel->clients->client->iterateItems() as $uuid => $node) {
        $items[$uuid] = $node;
    }
    return count($items) === 2
        && isset($items[$uuids["developer"]], $items[$uuids["contractor"]])
        && nodeMatches($items[$uuids["developer"]], [
            "enabled" => "1", "name" => "developer", "pubkey" => $developerPublic,
            "psk" => "", "tunneladdress" => "10.250.0.10/32",
            "serveraddress" => "", "serverport" => "", "keepalive" => "5",
        ])
        && in_array((string)$items[$uuids["contractor"]]->tunneladdress, $allowedAddresses, true)
        && nodeMatches($items[$uuids["contractor"]], [
            "enabled" => $contractorEnabled, "name" => "contractor",
            "pubkey" => $contractorPublic, "psk" => "",
            "serveraddress" => "", "serverport" => "", "keepalive" => "5",
        ]);
}

$config = Config::getInstance();
$config->lock();

if (in_array($phase, ["fault", "repair", "revoke", "reenroll"], true)) {
    $clients = new Client();
    $contractor = null;
    foreach ($clients->clients->client->iterateItems() as $uuid => $node) {
        if ($uuid === $uuids["contractor"]) {
            $contractor = $node;
        }
    }

    $allowedAddresses = $phase === "repair"
        ? ["10.250.0.20/32", "10.250.0.21/32"]
        : ["10.250.0.20/32"];
    $allowedEnabled = in_array($phase, ["revoke", "reenroll"], true)
        ? ["0", "1"] : ["1"];
    $valid = false;
    foreach ($allowedEnabled as $enabled) {
        if (exactClients(
            $clients,
            $uuids,
            $developerPublic,
            $contractorPublic,
            $allowedAddresses,
            $enabled
        )) {
            $valid = true;
            break;
        }
    }
    if (!$valid || $contractor === null) {
        fwrite(STDERR, "existing peer state is not eligible for this focused change\n");
        exit(1);
    }

    if ($phase === "fault") {
        $contractor->tunneladdress = "10.250.0.21/32";
    } elseif ($phase === "repair") {
        $contractor->tunneladdress = "10.250.0.20/32";
    } elseif ($phase === "revoke") {
        $contractor->enabled = "0";
    } else {
        $contractor->enabled = "1";
    }
    $clients->serializeToConfig();
    $config->save();
    echo "focused peer state saved\n";
    exit(0);
}

if ($phase === "server") {
    /*
     * This phase is deliberately a separate PHP process. OPNsense 26.1's
     * ModelRelation cache must see the client records after they are saved.
     */
    $servers = new Server();
    $privateKey = "";
    foreach ($servers->servers->server->iterateItems() as $uuid => $node) {
        if ($uuid === $uuids["server"]
            && preg_match('/^[A-Za-z0-9+\/]{43}=$/', (string)$node->privkey)) {
            $candidate = (string)$node->privkey;
            $derived = derivePublicKey($candidate);
            if (preg_match('/^[A-Za-z0-9+\/]{43}=$/', $derived)
                && hash_equals($derived, (string)$node->pubkey)) {
                $privateKey = $candidate;
            }
        }
    }
    if ($privateKey === "") {
        $privateKey = generatePrivateKey();
    }
    $publicKey = derivePublicKey($privateKey);
    if (!preg_match('/^[A-Za-z0-9+\/]{43}=$/', $publicKey)) {
        fwrite(STDERR, "could not derive concentrator identity\n");
        exit(1);
    }
    foreach ($servers->servers->server->iterateItems() as $uuid => $node) {
        $servers->servers->server->del($uuid);
    }
    $server = $servers->servers->server->Add($uuids["server"]);
    $server->setNodes([
        "enabled" => "1",
        "name" => "remote_access",
        "instance" => "0",
        "pubkey" => $publicKey,
        "privkey" => $privateKey,
        "port" => "51820",
        "mtu" => "",
        "dns" => "",
        "tunneladdress" => "10.250.0.1/24",
        "disableroutes" => "0",
        "gateway" => "",
        "carp_depend_on" => "",
        "peers" => $uuids["developer"] . "," . $uuids["contractor"],
        "debug" => "0",
    ]);
    $servers->serializeToConfig();
    $config->save();
    echo "concentrator instance saved\n";
    exit(0);
}

if ($phase === "firewall") {
    $firewall = new FirewallFilter();
    foreach ($firewall->rules->rule->iterateItems() as $uuid => $node) {
        if ((string)$node->interface === "opt3"
            || str_starts_with((string)$node->description, "RA lab ")) {
            $firewall->rules->rule->del($uuid);
        }
    }
    $rules = [
        [$uuids["management"], "100", "block", "any", "10.250.0.0/24", "10.70.10.1/32", "", "1", "RA lab block VPN management"],
        [$uuids["dev_app"], "200", "pass", "TCP", "10.250.0.10/32", "10.70.10.10/32", "8443", "0", "RA lab allow developer app"],
        [$uuids["dev_jump"], "300", "pass", "TCP", "10.250.0.10/32", "10.70.10.20/32", "22", "0", "RA lab allow developer jump"],
        [$uuids["contractor_jump"], "400", "pass", "TCP", "10.250.0.20/32", "10.70.10.20/32", "22", "0", "RA lab allow contractor jump"],
        [$uuids["contractor_app"], "500", "block", "TCP", "10.250.0.20/32", "10.70.10.10/32", "8443", "1", "RA lab block contractor app"],
    ];
    foreach ($rules as $definition) {
        [$uuid, $sequence, $action, $protocol, $source, $destination, $port, $log, $description] = $definition;
        $rule = $firewall->rules->rule->Add($uuid);
        $rule->setNodes([
            "enabled" => "1", "statetype" => "keep", "sequence" => $sequence,
            "action" => $action, "quick" => "1", "interfacenot" => "0",
            "interface" => "opt3", "direction" => "in", "ipprotocol" => "inet",
            "protocol" => $protocol, "source_net" => $source, "source_not" => "0",
            "source_port" => "", "destination_net" => $destination,
            "destination_not" => "0", "destination_port" => $port,
            "disablereplyto" => "1", "log" => $log,
            "description" => $description,
        ]);
    }
    $firewall->serializeToConfig();
    $config->save();
    echo "concentrator policy saved\n";
    exit(0);
}

/* Base and clients phase: do not instantiate Server in this process. */
$xml = $config->object();
$removeInterfaces = [];
foreach ($xml->interfaces->children() as $name => $interface) {
    if ($name === "opt1" || $name === "opt2" || $name === "opt3"
        || in_array((string)$interface->if, ["vtnet1", "vtnet2", "wg0"], true)) {
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
$wan->addChild("ipaddr", "203.0.113.2");
$wan->addChild("subnet", "24");

$corp = $xml->interfaces->addChild("opt2");
$corp->addChild("enable", "1");
$corp->addChild("descr", "CORP");
$corp->addChild("if", "vtnet2");
$corp->addChild("ipaddr", "10.70.10.1");
$corp->addChild("subnet", "24");

/* Pre-register the stable logical interface that the native service creates. */
$wireguard = $xml->interfaces->addChild("opt3");
$wireguard->addChild("enable", "1");
$wireguard->addChild("descr", "REMOTE_ACCESS");
$wireguard->addChild("if", "wg0");

if (!isset($xml->filter)) {
    $xml->addChild("filter");
}
for ($index = count($xml->filter->rule) - 1; $index >= 0; --$index) {
    $rule = $xml->filter->rule[$index];
    $interfaces = preg_split('/,/', (string)$rule->interface);
    if (str_starts_with((string)$rule->descr, "RA lab ")
        || in_array("opt1", $interfaces, true)
        || in_array("opt2", $interfaces, true)) {
        unset($xml->filter->rule[$index]);
    }
}

function addLegacyPassRule($filter, $description, $interface, $source, $destination, $protocol = null, $port = null)
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
    $source === "any" ? $sourceNode->addChild("any") : $sourceNode->addChild("network", $source);
    $destinationNode = $rule->addChild("destination");
    $destination === "any" ? $destinationNode->addChild("any") : $destinationNode->addChild("network", $destination);
    if ($port !== null) {
        $destinationNode->addChild("port", (string)$port);
    }
}

addLegacyPassRule($xml->filter, "RA lab allow WAN WireGuard", "opt1", "any", "opt1", "udp", 51820);
addLegacyPassRule($xml->filter, "RA lab allow WAN diagnostic", "opt1", "any", "opt1", "icmp");

$general = new General();
$general->enabled = "1";
$general->serializeToConfig();

$clients = new Client();
foreach ($clients->clients->client->iterateItems() as $uuid => $node) {
    $clients->clients->client->del($uuid);
}
$developer = $clients->clients->client->Add($uuids["developer"]);
$developer->setNodes([
    "enabled" => "1", "name" => "developer", "pubkey" => $developerPublic,
    "psk" => "", "tunneladdress" => "10.250.0.10/32",
    "serveraddress" => "", "serverport" => "", "keepalive" => "5",
]);
$contractor = $clients->clients->client->Add($uuids["contractor"]);
$contractor->setNodes([
    "enabled" => "1", "name" => "contractor", "pubkey" => $contractorPublic,
    "psk" => "", "tunneladdress" => "10.250.0.20/32",
    "serveraddress" => "", "serverport" => "", "keepalive" => "5",
]);
$clients->serializeToConfig();
$config->save();
echo "concentrator base and clients saved\n";
