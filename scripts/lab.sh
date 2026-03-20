#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABS_DIR="$REPO_ROOT/labs"

usage() {
    cat <<'EOF'
Usage:
  lab.sh help
  lab.sh labs
  lab.sh topo [lab]
  lab.sh nodes [lab]
  lab.sh status [lab]
  lab.sh up|deploy [lab]
  lab.sh down|destroy [lab]
  lab.sh check [lab]
  lab.sh cli [lab] <node>
  lab.sh sh|shell|bash [lab] <node>
  lab.sh exec|cmd [lab] <node> [--] <command...>
  lab.sh capture [lab] <node> <iface> [display-filter]
  lab.sh pcap [lab] <node> <iface> [outfile.pcap]
  lab.sh read <pcap-file> [tshark-args...]

Notes:
  - [lab] can be omitted when your current directory is inside labs/<lab>/.
  - cli picks the best interactive CLI for the node type:
    ceos -> Cli, srl -> sr_cli, FRR-like linux -> vtysh, otherwise bash/sh.
  - Compatibility aliases are kept for: deploy, destroy, list, vtysh, Cli, bash, cmd.
  - check runs automated assertions against a deployed lab and reports pass/fail.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

print_labs() {
    local found=0
    local path
    for path in "$LABS_DIR"/*; do
        [[ -d "$path" ]] || continue
        if [[ -f "$path/topology.clab.yml" || -f "$path/topology.yml" ]]; then
            printf '%s\n' "$(basename "$path")"
            found=1
        fi
    done
    [[ $found -eq 1 ]] || die "no labs found under $LABS_DIR"
}

infer_lab_from_cwd() {
    case "$PWD/" in
        "$LABS_DIR"/*)
            local rest="${PWD#"$LABS_DIR"/}"
            printf '%s\n' "${rest%%/*}"
            ;;
    esac
}

resolve_lab() {
    local candidate="${1:-}"

    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate="$(infer_lab_from_cwd || true)"
    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    echo "Available labs:" >&2
    print_labs >&2
    die "lab is required"
}

resolve_topology() {
    local lab="$1"
    local topo="$LABS_DIR/$lab/topology.clab.yml"
    [[ -f "$topo" ]] || topo="$LABS_DIR/$lab/topology.yml"
    [[ -f "$topo" ]] || die "topology not found in $LABS_DIR/$lab/"
    printf '%s\n' "$topo"
}

topology_lab_name() {
    local topo="$1"
    awk '/^name:[[:space:]]*/ { print $2; exit }' "$topo"
}

list_topology_nodes() {
    local topo="$1"
    awk '
        function emit_node() {
            if (node != "") {
                node_kind = (kind != "" ? kind : default_kind)
                node_image = (image != "" ? image : default_image)
                printf "%s\t%s\t%s\n", node, node_kind, node_image
            }
        }
        /^topology:/ { in_topology=1; next }
        !in_topology { next }
        /^  defaults:/ { in_defaults=1; in_nodes=0; next }
        /^  nodes:/ { in_nodes=1; in_defaults=0; next }
        /^  links:/ { emit_node(); node=""; exit }
        in_defaults {
            if ($0 ~ /^    kind:[[:space:]]*/) {
                sub(/^    kind:[[:space:]]*/, "", $0)
                default_kind=$0
            } else if ($0 ~ /^    image:[[:space:]]*/) {
                sub(/^    image:[[:space:]]*/, "", $0)
                default_image=$0
            }
            next
        }
        in_nodes {
            if ($0 ~ /^    [A-Za-z0-9_-]+:[[:space:]]*$/) {
                emit_node()
                node=$0
                sub(/^    /, "", node)
                sub(/:[[:space:]]*$/, "", node)
                kind=""
                image=""
                next
            }
            if ($0 ~ /^      kind:[[:space:]]*/) {
                kind=$0
                sub(/^      kind:[[:space:]]*/, "", kind)
            } else if ($0 ~ /^      image:[[:space:]]*/) {
                image=$0
                sub(/^      image:[[:space:]]*/, "", image)
            }
        }
        END { emit_node() }
    ' "$topo"
}

lookup_node_field() {
    local topo="$1"
    local node="$2"
    local field="$3"

    list_topology_nodes "$topo" | awk -F '\t' -v node="$node" -v field="$field" '
        $1 == node {
            if (field == "kind") {
                print $2
            } else if (field == "image") {
                print $3
            }
            exit
        }
    '
}

require_container() {
    local container="$1"
    docker inspect "$container" >/dev/null 2>&1 || die "container $container is not running"
}

container_shell() {
    local container="$1"
    if docker exec "$container" sh -lc 'exit 0' >/dev/null 2>&1; then
        printf '%s\n' "sh"
    elif docker exec "$container" bash -lc 'exit 0' >/dev/null 2>&1; then
        printf '%s\n' "bash"
    else
        printf '%s\n' ""
    fi
}

resolve_cli_command() {
    local topo="$1"
    local node="$2"
    local container="$3"
    local kind image shell_cmd

    kind="$(lookup_node_field "$topo" "$node" kind)"
    image="$(lookup_node_field "$topo" "$node" image)"

    case "$kind" in
        ceos)
            printf '%s\n' "Cli"
            return 0
            ;;
        vyosnetworks_vyos)
            printf '%s\n' "__vyos__"
            return 0
            ;;
        srl)
            printf '%s\n' "sr_cli"
            return 0
            ;;
    esac

    shell_cmd="$(container_shell "$container")"
    if [[ -n "$shell_cmd" ]] && docker exec "$container" "$shell_cmd" -lc 'command -v vtysh >/dev/null 2>&1'; then
        printf '%s\n' "vtysh"
        return 0
    fi

    if [[ "$image" == *frr* ]]; then
        printf '%s\n' "vtysh"
        return 0
    fi

    if docker exec "$container" bash -lc 'exit 0' >/dev/null 2>&1; then
        printf '%s\n' "bash"
    elif [[ -n "$shell_cmd" ]]; then
        printf '%s\n' "$shell_cmd"
    else
        die "could not determine an interactive CLI for $node"
    fi
}

print_nodes() {
    local lab="$1"
    local topo="$2"

    printf '%-24s %-12s %s\n' "NODE" "KIND" "IMAGE"
    list_topology_nodes "$topo" | while IFS=$'\t' read -r node kind image; do
        printf '%-24s %-12s %s\n' "$node" "${kind:-unknown}" "${image:-unknown}"
    done
}

cmd_help() {
    usage
}

cmd_labs() {
    print_labs
}

cmd_topo() {
    local lab
    lab="$(resolve_lab "${1:-}")"
    resolve_topology "$lab"
}

cmd_nodes() {
    local lab topo
    lab="$(resolve_lab "${1:-}")"
    topo="$(resolve_topology "$lab")"
    print_nodes "$lab" "$topo"
}

cmd_status() {
    local lab="${1:-}"

    if [[ -n "$lab" ]]; then
        local topo
        topo="$(resolve_topology "$lab")"
        containerlab inspect --topo "$topo"
        return 0
    fi

    local rows
    rows="$(docker ps --format '{{.Names}}\t{{.Status}}' | awk -F '\t' '$1 ~ /^clab-/ { print }')"
    if [[ -z "$rows" ]]; then
        echo "No running containerlab containers."
        return 0
    fi

    printf '%-40s %s\n' "CONTAINER" "STATUS"
    printf '%s\n' "$rows" | while IFS=$'\t' read -r name status; do
        printf '%-40s %s\n' "$name" "$status"
    done
}

cmd_up() {
    local lab topo
    lab="$(resolve_lab "${1:-}")"
    topo="$(resolve_topology "$lab")"
    containerlab deploy --topo "$topo" --reconfigure
}

cmd_down() {
    local lab topo
    lab="$(resolve_lab "${1:-}")"
    topo="$(resolve_topology "$lab")"
    containerlab destroy --topo "$topo" --cleanup
}

cmd_cli() {
    local lab="$1"
    local node="$2"
    local topo lab_name container cli_cmd

    [[ -n "$node" ]] || die "node required"
    topo="$(resolve_topology "$lab")"
    lab_name="$(topology_lab_name "$topo")"
    container="clab-${lab_name}-${node}"
    require_container "$container"
    cli_cmd="$(resolve_cli_command "$topo" "$node" "$container")"

    if [[ "$cli_cmd" == "__vyos__" ]]; then
        echo "Connecting to $node (VyOS)"
        docker exec -it "$container" bash -lc 'exec su - admin'
        return
    fi

    echo "Connecting to $node via $cli_cmd"
    docker exec -it "$container" "$cli_cmd"
}

cmd_shell() {
    local lab="$1"
    local node="$2"
    local topo lab_name container shell_cmd

    [[ -n "$node" ]] || die "node required"
    topo="$(resolve_topology "$lab")"
    lab_name="$(topology_lab_name "$topo")"
    container="clab-${lab_name}-${node}"
    require_container "$container"
    shell_cmd="$(container_shell "$container")"
    [[ -n "$shell_cmd" ]] || die "no interactive shell found in $container"
    docker exec -it "$container" "$shell_cmd"
}

cmd_exec() {
    local lab="$1"
    local node="$2"
    shift 2

    [[ -n "$node" ]] || die "node required"
    [[ $# -gt 0 ]] || die "command required"
    [[ "${1:-}" == "--" ]] && shift
    [[ $# -gt 0 ]] || die "command required"

    local topo lab_name container
    topo="$(resolve_topology "$lab")"
    lab_name="$(topology_lab_name "$topo")"
    container="clab-${lab_name}-${node}"
    require_container "$container"
    docker exec "$container" "$@"
}

cmd_capture() {
    local lab="$1"
    local node="$2"
    local iface="$3"
    local filter="${4:-}"
    local topo lab_name container pid
    local tshark_args=()

    [[ -n "$node" && -n "$iface" ]] || die "Usage: lab.sh capture [lab] <node> <iface> [display-filter]"
    topo="$(resolve_topology "$lab")"
    lab_name="$(topology_lab_name "$topo")"
    container="clab-${lab_name}-${node}"
    require_container "$container"
    pid="$(docker inspect --format '{{.State.Pid}}' "$container")"
    [[ -n "$filter" ]] && tshark_args=(-Y "$filter")

    echo "Capturing on $container $iface (PID $pid) - Ctrl-C to stop"
    sudo nsenter -t "$pid" -n -- tcpdump -U -i "$iface" -w - 2>/dev/null \
        | tshark -r - "${tshark_args[@]}"
}

cmd_pcap() {
    local lab="$1"
    local node="$2"
    local iface="$3"
    local outfile="$4"
    local topo lab_name container pid

    [[ -n "$node" && -n "$iface" ]] || die "Usage: lab.sh pcap [lab] <node> <iface> [outfile.pcap]"
    topo="$(resolve_topology "$lab")"
    lab_name="$(topology_lab_name "$topo")"
    container="clab-${lab_name}-${node}"
    require_container "$container"
    pid="$(docker inspect --format '{{.State.Pid}}' "$container")"
    outfile="${outfile:-/tmp/${lab_name}-${node}-capture.pcap}"

    echo "Capturing on $container $iface (PID $pid) -> $outfile - Ctrl-C to stop"
    sudo nsenter -t "$pid" -n -- tcpdump -U -i "$iface" -w - 2>/dev/null > "$outfile"
    echo "Saved to $outfile"
}

cmd_read() {
    local file="${1:-}"
    [[ -n "$file" ]] || die "Usage: lab.sh read <pcap-file> [tshark-args...]"
    shift
    tshark -r "$file" "$@"
}

main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        help|-h|--help)
            cmd_help
            ;;
        labs)
            cmd_labs
            ;;
        topo)
            cmd_topo "${1:-}"
            ;;
        nodes)
            cmd_nodes "${1:-}"
            ;;
        status|list)
            cmd_status "${1:-}"
            ;;
        check)
            local lab
            lab="$(resolve_lab "${1:-}")"
            local check_script="$LABS_DIR/$lab/check.sh"
            [[ -f "$check_script" ]] || die "no check.sh found for lab $lab"
            bash "$check_script"
            ;;
        up|deploy)
            cmd_up "${1:-}"
            ;;
        down|destroy)
            cmd_down "${1:-}"
            ;;
        cli)
            local lab node
            lab="$(resolve_lab "${1:-}")"
            if [[ $# -ge 2 ]]; then
                node="$2"
            elif [[ $# -ge 1 && "$lab" != "$1" ]]; then
                node="$1"
            else
                node=""
            fi
            cmd_cli "$lab" "$node"
            ;;
        sh|shell)
            local lab node
            lab="$(resolve_lab "${1:-}")"
            if [[ $# -ge 2 ]]; then
                node="$2"
            elif [[ $# -ge 1 && "$lab" != "$1" ]]; then
                node="$1"
            else
                node=""
            fi
            cmd_shell "$lab" "$node"
            ;;
        bash)
            local lab node
            lab="$(resolve_lab "${1:-}")"
            if [[ $# -ge 2 ]]; then
                node="$2"
            elif [[ $# -ge 1 && "$lab" != "$1" ]]; then
                node="$1"
            else
                node=""
            fi
            cmd_shell "$lab" "$node"
            ;;
        vtysh)
            local lab node
            lab="$(resolve_lab "${1:-}")"
            if [[ $# -ge 2 ]]; then
                node="$2"
            elif [[ $# -ge 1 && "$lab" != "$1" ]]; then
                node="$1"
            else
                node=""
            fi
            cmd_cli "$lab" "$node"
            ;;
        Cli)
            local lab node
            lab="$(resolve_lab "${1:-}")"
            if [[ $# -ge 2 ]]; then
                node="$2"
            elif [[ $# -ge 1 && "$lab" != "$1" ]]; then
                node="$1"
            else
                node=""
            fi
            cmd_cli "$lab" "$node"
            ;;
        exec|cmd)
            local lab node
            lab="$(resolve_lab "${1:-}")"
            if [[ $# -ge 2 ]]; then
                node="$2"
                shift 2
            elif [[ $# -ge 1 && "$lab" != "$1" ]]; then
                node="$1"
                shift 1
            else
                node=""
                shift $# || true
            fi
            cmd_exec "$lab" "$node" "$@"
            ;;
        capture)
            local lab node iface filter
            lab="$(resolve_lab "${1:-}")"
            if [[ $# -ge 3 ]]; then
                node="$2"
                iface="$3"
                filter="${4:-}"
            elif [[ $# -ge 2 && "$lab" != "$1" ]]; then
                node="$1"
                iface="$2"
                filter="${3:-}"
            else
                node=""
                iface=""
                filter=""
            fi
            cmd_capture "$lab" "$node" "$iface" "$filter"
            ;;
        pcap)
            local lab node iface outfile
            lab="$(resolve_lab "${1:-}")"
            if [[ $# -ge 3 ]]; then
                node="$2"
                iface="$3"
                outfile="${4:-}"
            elif [[ $# -ge 2 && "$lab" != "$1" ]]; then
                node="$1"
                iface="$2"
                outfile="${3:-}"
            else
                node=""
                iface=""
                outfile=""
            fi
            cmd_pcap "$lab" "$node" "$iface" "$outfile"
            ;;
        read)
            cmd_read "$@"
            ;;
        *)
            usage
            die "unknown command '$command'"
            ;;
    esac
}

main "$@"
