<?php

/* Read-only, secret-safe saved-state grader streamed over loopback SSH. */

require_once("config.inc");

use OPNsense\Core\Config;
use OPNsense\Firewall\Filter as FirewallFilter;
use OPNsense\Wireguard\Client;
use OPNsense\Wireguard\General;
use OPNsense\Wireguard\Server;

$developerPublic = getenv("RA_DEV_PUBLIC");
$contractorPublic = getenv("RA_CONTRACTOR_PUBLIC");
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

function derivePublicKey($privateKey)
{
    $spec = [0 => ["pipe", "r"], 1 => ["pipe", "w"], 2 => ["pipe", "w"]];
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

$keysValid = preg_match('/^[A-Za-z0-9+\/]{43}=$/', $developerPublic) === 1
    && preg_match('/^[A-Za-z0-9+\/]{43}=$/', $contractorPublic) === 1
    && !hash_equals($developerPublic, $contractorPublic);
emitResult("input_keys", $keysValid);

$config = Config::getInstance();
$xml = $config->object();
$opt1 = isset($xml->interfaces->opt1) ? $xml->interfaces->opt1 : null;
$opt2 = isset($xml->interfaces->opt2) ? $xml->interfaces->opt2 : null;
$dataNicOwners = 0;
$wgOwners = 0;
$wgInterfaceName = "";
foreach ($xml->interfaces->children() as $name => $interface) {
    if (in_array((string)$interface->if, ["vtnet1", "vtnet2"], true)) {
        ++$dataNicOwners;
    }
    if ((string)$interface->if === "wg0") {
        ++$wgOwners;
        $wgInterfaceName = (string)$name;
    }
}
emitResult("interfaces", $opt1 !== null && $opt2 !== null
    && nodeMatches($opt1, [
        "enable" => "1", "descr" => "WAN_DATA", "if" => "vtnet1",
        "ipaddr" => "203.0.113.2", "subnet" => "24",
    ])
    && nodeMatches($opt2, [
        "enable" => "1", "descr" => "CORP", "if" => "vtnet2",
        "ipaddr" => "10.70.10.1", "subnet" => "24",
    ])
    && $dataNicOwners === 2);
emitResult("wg_registered", $wgOwners === 1 && $wgInterfaceName === "opt3");

$expectedLegacyRules = [
    "RA lab allow WAN WireGuard" => ["opt1", "udp", "51820", "any", "network:opt1"],
    "RA lab allow WAN diagnostic" => ["opt1", "icmp", "", "any", "network:opt1"],
];
$actualLegacyRules = [];
$legacyRuleCount = 0;
if (isset($xml->filter)) {
    foreach ($xml->filter->rule as $rule) {
        $interfaces = preg_split('/,/', (string)$rule->interface);
        if (str_starts_with((string)$rule->descr, "RA lab ")
            || in_array("opt1", $interfaces, true)
            || in_array("opt2", $interfaces, true)) {
            ++$legacyRuleCount;
            $actualLegacyRules[(string)$rule->descr] = [
                (string)$rule->interface,
                (string)$rule->protocol,
                (string)$rule->destination->port,
                endpointValue($rule->source),
                endpointValue($rule->destination),
            ];
        }
    }
}
ksort($actualLegacyRules);
ksort($expectedLegacyRules);
emitResult("legacy_rules", $legacyRuleCount === 2
    && $actualLegacyRules === $expectedLegacyRules);

$general = new General();
emitResult("general", (string)$general->enabled === "1");

$clients = new Client();
$clientItems = [];
foreach ($clients->clients->client->iterateItems() as $uuid => $node) {
    $clientItems[$uuid] = $node;
}
emitResult("client_inventory", count($clientItems) === 2
    && isset($clientItems[$uuids["developer"]], $clientItems[$uuids["contractor"]]));
emitResult("developer", $keysValid && isset($clientItems[$uuids["developer"]])
    && nodeMatches($clientItems[$uuids["developer"]], [
        "enabled" => "1", "name" => "developer", "pubkey" => $developerPublic,
        "psk" => "", "tunneladdress" => "10.250.0.10/32",
        "serveraddress" => "", "serverport" => "", "keepalive" => "5",
    ]));
emitResult("contractor", $keysValid && isset($clientItems[$uuids["contractor"]])
    && nodeMatches($clientItems[$uuids["contractor"]], [
        "enabled" => "1", "name" => "contractor", "pubkey" => $contractorPublic,
        "psk" => "", "tunneladdress" => "10.250.0.20/32",
        "serveraddress" => "", "serverport" => "", "keepalive" => "5",
    ]));

/* Instantiate Server only after Client has read the already-persisted peers. */
$servers = new Server();
$serverItems = [];
foreach ($servers->servers->server->iterateItems() as $uuid => $node) {
    $serverItems[$uuid] = $node;
}
$serverExact = count($serverItems) === 1 && isset($serverItems[$uuids["server"]])
    && nodeMatches($serverItems[$uuids["server"]], [
        "enabled" => "1", "name" => "remote_access", "instance" => "0",
        "port" => "51820", "mtu" => "", "dns" => "",
        "tunneladdress" => "10.250.0.1/24", "disableroutes" => "0",
        "gateway" => "", "carp_depend_on" => "", "debug" => "0",
    ]);
if ($serverExact) {
    $peerRelation = array_filter(explode(',', (string)$serverItems[$uuids["server"]]->peers));
    sort($peerRelation);
    $expectedRelation = [$uuids["developer"], $uuids["contractor"]];
    sort($expectedRelation);
    $privateKey = (string)$serverItems[$uuids["server"]]->privkey;
    $publicKey = (string)$serverItems[$uuids["server"]]->pubkey;
    $serverExact = $peerRelation === $expectedRelation
        && preg_match('/^[A-Za-z0-9+\/]{43}=$/', $privateKey) === 1
        && preg_match('/^[A-Za-z0-9+\/]{43}=$/', $publicKey) === 1
        && hash_equals($publicKey, derivePublicKey($privateKey));
}
emitResult("server", $serverExact);

$expectedFirewall = [
    $uuids["management"] => ["100", "block", "any", "10.250.0.0/24", "10.70.10.1/32", "", "1", "RA lab block VPN management"],
    $uuids["dev_app"] => ["200", "pass", "TCP", "10.250.0.10/32", "10.70.10.10/32", "8443", "0", "RA lab allow developer app"],
    $uuids["dev_jump"] => ["300", "pass", "TCP", "10.250.0.10/32", "10.70.10.20/32", "22", "0", "RA lab allow developer jump"],
    $uuids["contractor_jump"] => ["400", "pass", "TCP", "10.250.0.20/32", "10.70.10.20/32", "22", "0", "RA lab allow contractor jump"],
    $uuids["contractor_app"] => ["500", "block", "TCP", "10.250.0.20/32", "10.70.10.10/32", "8443", "1", "RA lab block contractor app"],
];
$firewall = new FirewallFilter();
$actualFirewall = [];
foreach ($firewall->rules->rule->iterateItems() as $uuid => $node) {
    if ((string)$node->interface === "opt3"
        || str_starts_with((string)$node->description, "RA lab ")) {
        $actualFirewall[$uuid] = $node;
    }
}
$firewallExact = count($actualFirewall) === 5;
foreach ($expectedFirewall as $uuid => $values) {
    [$sequence, $action, $protocol, $source, $destination, $port, $log, $description] = $values;
    $firewallExact = $firewallExact && isset($actualFirewall[$uuid])
        && nodeMatches($actualFirewall[$uuid], [
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
emitResult("firewall", $firewallExact);
