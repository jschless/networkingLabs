#!/usr/bin/env bash
# containerlab helper script
#
# Usage:
#   lab.sh deploy   <lab>                          Deploy (or redeploy) a lab
#   lab.sh destroy  <lab>                          Destroy a lab and clean up
#   lab.sh list     <lab>                          Show running nodes and management IPs
#   lab.sh vtysh    <lab> <node>                   Open vtysh on a node  (FRR router CLI)
#   lab.sh Cli      <lab> <node>                   Open EOS Cli on a cEOS node
#   lab.sh bash     <lab> <node>                   Open a bash shell on a node
#   lab.sh cmd      <lab> <node> <cmd...>          Run a command on a node
#   lab.sh capture  <lab> <node> <iface> [filter]  Live capture → tshark decode on host
#   lab.sh pcap     <lab> <node> <iface> [out.pcap] Capture to pcap file on host
#   lab.sh read     <file> [tshark-args...]        Analyze a saved pcap file
#
# <lab> is the directory name under ~/containerlab/labs/
# <node> is the short node name, e.g. pe1, rr1, ce1
#
# capture/pcap use nsenter to enter the container's network namespace from the
# host and pipe raw pcap to tshark — no need for tcpdump inside the container.
# Requires sudo for nsenter.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABS_DIR="$REPO_ROOT/labs"

usage() {
    sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
    exit 1
}

[[ $# -lt 1 ]] && usage

CMD="$1"

# Early exit for commands that don't need a topology
if [[ "$CMD" == "read" ]]; then
    FILE="${2:-}"
    [[ -z "$FILE" ]] && { echo "Usage: lab.sh read <pcap-file> [tshark-args...]"; exit 1; }
    shift 2
    tshark -r "$FILE" "$@"
    exit 0
fi

[[ $# -lt 2 ]] && usage

LAB="$2"
NODE="${3:-}"

# Try .clab.yml first, then plain .yml
TOPO="$LABS_DIR/$LAB/topology.clab.yml"
[[ ! -f "$TOPO" ]] && TOPO="$LABS_DIR/$LAB/topology.yml"
[[ ! -f "$TOPO" ]] && { echo "ERROR: topology not found in $LABS_DIR/$LAB/"; exit 1; }

# Derive the container name prefix from the topology name field
LAB_NAME=$(grep '^name:' "$TOPO" | awk '{print $2}')
CONTAINER="clab-${LAB_NAME}-${NODE}"

case "$CMD" in
    deploy)
        containerlab deploy --topo "$TOPO" --reconfigure
        ;;
    destroy)
        containerlab destroy --topo "$TOPO" --cleanup
        ;;
    list)
        containerlab inspect --topo "$TOPO"
        ;;
    vtysh)
        [[ -z "$NODE" ]] && { echo "ERROR: node required  (e.g. pe1, rr1)"; exit 1; }
        echo "Connecting to $NODE — type 'exit' or Ctrl-D to leave vtysh"
        docker exec -it "$CONTAINER" vtysh
        ;;
    Cli)
        [[ -z "$NODE" ]] && { echo "ERROR: node required  (e.g. edge, core1)"; exit 1; }
        docker exec -it "$CONTAINER" Cli
        ;;
    bash)
        [[ -z "$NODE" ]] && { echo "ERROR: node required"; exit 1; }
        docker exec -it "$CONTAINER" bash
        ;;
    cmd)
        [[ -z "$NODE" || -z "${4:-}" ]] && { echo "ERROR: node and command required"; exit 1; }
        shift 3
        docker exec "$CONTAINER" bash -c "$*"
        ;;
    capture)
        IFACE="${4:-}"
        FILTER="${5:-}"
        [[ -z "$NODE" || -z "$IFACE" ]] && { echo "Usage: lab.sh capture <lab> <node> <iface> [display-filter]"; exit 1; }
        PID=$(docker inspect --format '{{.State.Pid}}' "$CONTAINER")
        echo "Capturing on $CONTAINER $IFACE (PID $PID) — Ctrl-C to stop"
        sudo nsenter -t "$PID" -n -- tcpdump -U -i "$IFACE" -w - 2>/dev/null \
            | tshark -r - ${FILTER:+-Y "$FILTER"}
        ;;
    pcap)
        IFACE="${4:-}"
        OUTFILE="${5:-/tmp/${LAB_NAME}-${NODE}-capture.pcap}"
        [[ -z "$NODE" || -z "$IFACE" ]] && { echo "Usage: lab.sh pcap <lab> <node> <iface> [outfile.pcap]"; exit 1; }
        PID=$(docker inspect --format '{{.State.Pid}}' "$CONTAINER")
        echo "Capturing on $CONTAINER $IFACE (PID $PID) → $OUTFILE — Ctrl-C to stop"
        sudo nsenter -t "$PID" -n -- tcpdump -U -i "$IFACE" -w - 2>/dev/null > "$OUTFILE"
        echo "Saved to $OUTFILE"
        ;;
    *)
        echo "ERROR: unknown command '$CMD'"
        usage
        ;;
esac
