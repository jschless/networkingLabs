<?php

/* Read-only, secret-safe OPNsense 26.1 live-state grader. */

$developerPublic = getenv("RA_DEV_PUBLIC");
$contractorPublic = getenv("RA_CONTRACTOR_PUBLIC");

function emitResult($name, $result)
{
    echo $name . "=" . ($result ? "1" : "0") . "\n";
}

function commandOutput($command)
{
    $output = shell_exec($command . " 2>/dev/null");
    return $output === null ? "" : $output;
}

function recentTimestamp($timestamp)
{
    return ctype_digit((string)$timestamp)
        && (int)$timestamp > 0
        && time() >= (int)$timestamp
        && time() - (int)$timestamp <= 180;
}

function peerField($output, $publicKey, $fieldIndex)
{
    foreach (preg_split('/\R/', trim($output)) as $line) {
        $fields = preg_split('/\s+/', trim($line));
        if (count($fields) > $fieldIndex && $fields[0] === $publicKey) {
            return $fields[$fieldIndex];
        }
    }
    return "";
}

function labeledRuleLine($rules, $label)
{
    foreach (preg_split('/\R/', $rules) as $line) {
        if (str_contains($line, 'label "' . $label . '"')) {
            return $line;
        }
    }
    return "";
}

function labeledPacketCount($rules, $label)
{
    $blocks = preg_split('/(?=^@\d+[[:space:]])/m', $rules);
    foreach ($blocks as $block) {
        if (str_contains($block, 'label "' . $label . '"')
            && preg_match('/Packets:[[:space:]]*([0-9]+)/', $block, $matches)) {
            return (int)$matches[1];
        }
    }
    return -1;
}

$version = trim(commandOutput('/usr/local/sbin/opnsense-version'));
$uname = trim(commandOutput('/usr/bin/uname -m'));
emitResult("platform", preg_match('/(^|[[:space:]])26\.1\.6_2([[:space:]]|$)/', $version) === 1
    && $uname === "amd64");

$wan = commandOutput('/sbin/ifconfig vtnet1');
$corp = commandOutput('/sbin/ifconfig vtnet2');
$wireguard = commandOutput('/sbin/ifconfig wg0');
emitResult("interfaces", preg_match('/inet 203\.0\.113\.2[[:space:]]+netmask 0xffffff00/', $wan) === 1
    && preg_match('/inet 10\.70\.10\.1[[:space:]]+netmask 0xffffff00/', $corp) === 1
    && preg_match('/inet 10\.250\.0\.1[[:space:]]+netmask 0xffffff00/', $wireguard) === 1
    && str_contains($wan, "UP") && str_contains($corp, "UP") && str_contains($wireguard, "UP"));

$developerRoute = commandOutput('/sbin/route -n get 10.250.0.10');
$contractorRoute = commandOutput('/sbin/route -n get 10.250.0.20');
emitResult("routes", preg_match('/interface:[[:space:]]*wg0([[:space:]]|$)/', $developerRoute) === 1
    && preg_match('/interface:[[:space:]]*wg0([[:space:]]|$)/', $contractorRoute) === 1);

$serverPublic = trim(commandOutput('/usr/bin/wg show wg0 public-key'));
$listenPort = trim(commandOutput('/usr/bin/wg show wg0 listen-port'));
$peers = array_values(array_filter(preg_split('/\R/', trim(commandOutput('/usr/bin/wg show wg0 peers')))));
$expectedPeers = [$developerPublic, $contractorPublic];
sort($peers);
sort($expectedPeers);
emitResult("server", preg_match('/^[A-Za-z0-9+\/]{43}=$/', $serverPublic) === 1
    && $listenPort === "51820");
emitResult("peer_inventory", $peers === $expectedPeers);

$allowed = commandOutput('/usr/bin/wg show wg0 allowed-ips');
$latest = commandOutput('/usr/bin/wg show wg0 latest-handshakes');
$transfer = commandOutput('/usr/bin/wg show wg0 transfer');
emitResult("allowed_ips", peerField($allowed, $developerPublic, 1) === "10.250.0.10/32"
    && peerField($allowed, $contractorPublic, 1) === "10.250.0.20/32");
emitResult("handshakes", recentTimestamp(peerField($latest, $developerPublic, 1))
    && recentTimestamp(peerField($latest, $contractorPublic, 1)));
$developerReceived = peerField($transfer, $developerPublic, 1);
$developerSent = peerField($transfer, $developerPublic, 2);
$contractorReceived = peerField($transfer, $contractorPublic, 1);
$contractorSent = peerField($transfer, $contractorPublic, 2);
emitResult("transfers", ctype_digit($developerReceived) && ctype_digit($developerSent)
    && ctype_digit($contractorReceived) && ctype_digit($contractorSent)
    && (int)$developerReceived > 0 && (int)$developerSent > 0
    && (int)$contractorReceived > 0 && (int)$contractorSent > 0);

$pfRules = commandOutput('/sbin/pfctl -sr');
$labels = [
    "b3000000-0000-4000-8000-000000000001",
    "b3000000-0000-4000-8000-000000000002",
    "b3000000-0000-4000-8000-000000000003",
    "b3000000-0000-4000-8000-000000000004",
    "b3000000-0000-4000-8000-000000000005",
];
$positions = [];
foreach ($labels as $label) {
    $positions[] = strpos($pfRules, 'label "' . $label . '"');
}
$orderExact = !in_array(false, $positions, true)
    && $positions === array_values(array_unique($positions));
if ($orderExact) {
    $sorted = $positions;
    sort($sorted);
    $orderExact = $positions === $sorted;
}
$targetLineCount = preg_match_all('/^.*label "b3000000-0000-4000-8000-00000000000[1-5]".*$/m', $pfRules);
$wgRuleCount = preg_match_all('/^.* on wg0 .*$/m', $pfRules);
emitResult("pf_inventory", $targetLineCount === 5 && $wgRuleCount === 5 && $orderExact);

$management = labeledRuleLine($pfRules, $labels[0]);
$devApp = labeledRuleLine($pfRules, $labels[1]);
$devJump = labeledRuleLine($pfRules, $labels[2]);
$contractorJump = labeledRuleLine($pfRules, $labels[3]);
$contractorApp = labeledRuleLine($pfRules, $labels[4]);
emitResult("pf_scope", preg_match('/block .*in log quick on wg0 inet .*from 10\.250\.0\.0\/24 to 10\.70\.10\.1/', $management) === 1
    && preg_match('/pass in quick on wg0 inet proto tcp .*from 10\.250\.0\.10 to 10\.70\.10\.10 port = 8443/', $devApp) === 1
    && preg_match('/pass in quick on wg0 inet proto tcp .*from 10\.250\.0\.10 to 10\.70\.10\.20 port = ssh/', $devJump) === 1
    && preg_match('/pass in quick on wg0 inet proto tcp .*from 10\.250\.0\.20 to 10\.70\.10\.20 port = ssh/', $contractorJump) === 1
    && preg_match('/block .*in log quick on wg0 inet proto tcp .*from 10\.250\.0\.20 to 10\.70\.10\.10 port = 8443/', $contractorApp) === 1);

$verboseRules = commandOutput('/sbin/pfctl -vvsr');
emitResult("denial_counters", labeledPacketCount($verboseRules, $labels[0]) > 0
    && labeledPacketCount($verboseRules, $labels[4]) > 0);
