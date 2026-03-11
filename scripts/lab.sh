#!/usr/bin/env bash
# containerlab helper script
#
# Usage:
#   lab.sh deploy   <lab>           Deploy (or redeploy) a lab
#   lab.sh destroy  <lab>           Destroy a lab and clean up
#   lab.sh list     <lab>           Show running nodes and management IPs
#   lab.sh vtysh    <lab> <node>    Open vtysh on a node  (router CLI)
#   lab.sh bash     <lab> <node>    Open a bash shell on a node
#   lab.sh cmd      <lab> <node> <cmd...>  Run a command on a node
#
# <lab> is the directory name under ~/containerlab/labs/
# <node> is the short node name, e.g. pe1, rr1, ce1

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABS_DIR="$REPO_ROOT/labs"

usage() {
    sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
    exit 1
}

[[ $# -lt 2 ]] && usage

CMD="$1"
LAB="$2"
NODE="${3:-}"

TOPO="$LABS_DIR/$LAB/topology.clab.yml"
[[ ! -f "$TOPO" ]] && { echo "ERROR: topology not found: $TOPO"; exit 1; }

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
    bash)
        [[ -z "$NODE" ]] && { echo "ERROR: node required"; exit 1; }
        docker exec -it "$CONTAINER" bash
        ;;
    cmd)
        [[ -z "$NODE" || -z "${4:-}" ]] && { echo "ERROR: node and command required"; exit 1; }
        shift 3
        docker exec "$CONTAINER" bash -c "$*"
        ;;
    *)
        echo "ERROR: unknown command '$CMD'"
        usage
        ;;
esac
