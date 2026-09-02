<?php

/* Read-only OPNsense 26.1 live-state grader streamed over loopback SSH. */

$role = getenv("NATT_ROLE");
if (!in_array($role, ["hq", "branch"], true)) {
    exit(64);
}

$isHq = $role === "hq";
$roleIndex = $isHq ? "1" : "2";
$connectionUuid = "a2000000-0000-4000-8000-00000000000{$roleIndex}";
$childUuid = "a5000000-0000-4000-8000-00000000000{$roleIndex}";
$wanIp = $isHq ? "198.51.100.2" : "10.200.0.2";
$wanGateway = $isHq ? "198.51.100.1" : "10.200.0.1";
$lanIp = $isHq ? "10.10.1.1" : "10.20.1.1";
$localId = $isHq ? "hq.lab" : "branch.lab";
$remoteId = $isHq ? "branch.lab" : "hq.lab";
$localTs = $isHq ? "10.10.1.0/24" : "10.20.1.0/24";
$remoteTs = $isHq ? "10.20.1.0/24" : "10.10.1.0/24";
$localOuter = $wanIp;
$remoteOuter = $isHq ? "198.51.100.1" : "198.51.100.2";

function emitResult($name, $result)
{
    echo $name . "=" . ($result ? "1" : "0") . "\n";
}

function commandOutput($command)
{
    $output = shell_exec($command . " 2>/dev/null");
    return $output === null ? "" : $output;
}

function valueAt($array, $names, $default = null)
{
    if (!is_array($array)) {
        return $default;
    }
    foreach ($names as $name) {
        if (array_key_exists($name, $array)) {
            return $array[$name];
        }
    }
    return $default;
}

function valuesEqual($actual, $expected)
{
    $actualValues = is_array($actual) ? array_values($actual) : [$actual];
    $expectedValues = is_array($expected) ? array_values($expected) : [$expected];
    $actualValues = array_map('strval', $actualValues);
    $expectedValues = array_map('strval', $expectedValues);
    sort($actualValues);
    sort($expectedValues);
    return $actualValues === $expectedValues;
}

function packetCounterTotal($value)
{
    if (!is_array($value)) {
        return 0;
    }
    $total = 0;
    foreach ($value as $key => $child) {
        if (is_array($child)) {
            $total += packetCounterTotal($child);
        } elseif (is_string($key) && str_contains($key, "packets") && is_numeric($child)) {
            $total += (int)$child;
        }
    }
    return $total;
}

$version = trim(commandOutput('/usr/local/sbin/opnsense-version'));
$uname = trim(commandOutput('/usr/bin/uname -m'));
emitResult("platform", preg_match('/(^|[[:space:]])26\.1([.[:space:]]|$)/', $version) === 1
    && $uname === "amd64");

$wan = commandOutput('/sbin/ifconfig vtnet1');
$lan = commandOutput('/sbin/ifconfig vtnet2');
emitResult("interfaces", preg_match('/inet ' . preg_quote($wanIp, '/') . '[[:space:]]+netmask 0xffffff00/', $wan) === 1
    && preg_match('/inet ' . preg_quote($lanIp, '/') . '[[:space:]]+netmask 0xffffff00/', $lan) === 1
    && str_contains($wan, "UP") && str_contains($lan, "UP"));

$route = commandOutput('/sbin/route -n get default');
emitResult("default_route", preg_match('/gateway:[[:space:]]*' . preg_quote($wanGateway, '/') . '([[:space:]]|$)/', $route) === 1
    && preg_match('/interface:[[:space:]]*vtnet1([[:space:]]|$)/', $route) === 1);

$pfRules = commandOutput('/sbin/pfctl -sr');
$enc0Pattern = '/pass in quick on enc0 inet from '
    . preg_quote($remoteTs, '/') . ' to ' . preg_quote($localTs, '/')
    . '([[:space:]]|$)/';
$filterActive = preg_match_all('/pass in quick on enc0 inet/', $pfRules) === 1
    && preg_match($enc0Pattern, $pfRules) === 1
    && preg_match('/pass in quick on vtnet2 inet/', $pfRules) === 1;
if ($isHq) {
    $filterActive = $filterActive
        && preg_match('/pass in quick on vtnet1[^\n]* inet proto udp [^\n]*port = (isakmp|500)/', $pfRules) === 1
        && preg_match('/pass in quick on vtnet1[^\n]* inet proto udp [^\n]*port = (ipsec-nat-t|4500)/', $pfRules) === 1
        && preg_match('/pass in quick on vtnet1[^\n]* inet proto icmp/', $pfRules) === 1;
}
emitResult("filter_rules", $filterActive);

$statusText = commandOutput('/usr/local/sbin/configctl ipsec list status');
$status = json_decode($statusText, true);
$connection = is_array($status) && count($status) === 1 && isset($status[$connectionUuid])
    ? $status[$connectionUuid] : null;
$configuredChildren = is_array($connection) ? valueAt($connection, ["children"], []) : [];
$sas = is_array($connection) ? valueAt($connection, ["sas"], []) : [];
$sa = is_array($sas) && count($sas) === 1 ? array_values($sas)[0] : null;
$childSas = is_array($sa) ? valueAt($sa, ["child-sas", "child_sas"], []) : [];
$childSa = is_array($childSas) && count($childSas) === 1 ? array_values($childSas)[0] : null;

emitResult("status_inventory", is_array($connection)
    && is_array($configuredChildren) && count($configuredChildren) === 1
    && isset($configuredChildren[$childUuid])
    && is_array($sa) && is_array($childSa));
emitResult("ike", is_array($sa)
    && valueAt($sa, ["state"]) === "ESTABLISHED"
    && in_array((string)valueAt($connection, ["version"]), ["2", "IKEv2"], true)
    && valueAt($connection, ["local-id", "local_id"]) === $localId
    && valueAt($connection, ["remote-id", "remote_id"]) === $remoteId
    && valueAt($sa, ["local-host", "local_host"]) === $localOuter
    && valueAt($sa, ["remote-host", "remote_host"]) === $remoteOuter
    && (string)valueAt($sa, ["local-port", "local_port"]) === "4500"
    && (string)valueAt($sa, ["remote-port", "remote_port"]) === "4500");
emitResult("natt", is_array($sa)
    && valueAt($sa, ["nat-any", "nat_any"]) === "yes"
    && valueAt($sa, [$isHq ? "nat-remote" : "nat-local", $isHq ? "nat_remote" : "nat_local"]) === "yes");
emitResult("ike_crypto", is_array($sa)
    && valueAt($sa, ["encr-alg", "encr"]) === "AES_CBC"
    && (string)valueAt($sa, ["encr-keysize", "encr_keysize", "keysize"]) === "256"
    && valueAt($sa, ["integ-alg", "integ"]) === "HMAC_SHA2_256_128"
    && valueAt($sa, ["prf-alg", "prf"]) === "PRF_HMAC_SHA2_256"
    && valueAt($sa, ["dh-group", "dh"]) === "MODP_2048");
emitResult("child", is_array($childSa)
    && valueAt($childSa, ["state"]) === "INSTALLED"
    && valueAt($childSa, ["mode"]) === "TUNNEL"
    && valueAt($childSa, ["protocol"]) === "ESP"
    && valueAt($childSa, ["encap"]) === "yes");
emitResult("child_crypto", is_array($childSa)
    && valueAt($childSa, ["encr-alg", "encr"]) === "AES_CBC"
    && (string)valueAt($childSa, ["encr-keysize", "encr_keysize", "keysize"]) === "256"
    && valueAt($childSa, ["integ-alg", "integ"]) === "HMAC_SHA2_256_128");
emitResult("selectors", is_array($childSa)
    && valuesEqual(valueAt($childSa, ["local-ts", "local_ts"], []), [$localTs])
    && valuesEqual(valueAt($childSa, ["remote-ts", "remote_ts"], []), [$remoteTs]));

echo "packet_counter=" . packetCounterTotal($childSa) . "\n";
