#!/bin/vbash
# Replace only the requested live map; save only for intrinsic startup use.
# shellcheck shell=bash disable=SC2121

# Validate and copy positional parameters before the VyOS template, which
# rewrites $@ while establishing its native configuration functions.
case ${1:-} in
    10.0.0.1|10.0.0.254) target=$1 ;;
    *) echo 'usage: set-map.sh 10.0.0.1|10.0.0.254 [--save]' >&2; exit 2 ;;
esac
case ${2:-} in
    '') persist=false ;;
    --save) persist=true ;;
    *) echo 'usage: set-map.sh 10.0.0.1|10.0.0.254 [--save]' >&2; exit 2 ;;
esac
(( $# <= 2 )) || {
    echo 'usage: set-map.sh 10.0.0.1|10.0.0.254 [--save]' >&2
    exit 2
}

# Native VyOS configuration aliases return benign nonzero statuses while
# applying valid commands, so this inner helper intentionally follows the
# sibling native pattern without shell errexit. The strict external caller
# verifies exact live/saved postconditions.
source /opt/vyatta/etc/functions/script-template

configure
# This scalar set adds an absent migration-stripped map and atomically replaces
# an existing map value; native `delete` is intentionally not used here.
set protocols nhrp tunnel tun0 map tunnel-ip 172.16.0.1 nbma "$target"
commit
if [[ "$persist" == true ]]; then
    save
fi
exit
