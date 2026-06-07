#!/usr/bin/env bash
set -euo pipefail

# Helper for the Enterprise IT 101 Docker Compose labs.
#
# These labs are NOT ContainerLab — scripts/lab.sh does not drive them.
# Lab 01 ships a standalone docker-compose.yml; Labs 02-12 are override files
# layered on base/docker-compose.yml. This wrapper hides the -f plumbing so you
# can run a lab with a single short command.

EIT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$EIT_DIR"

# Custom images built from images/<name>/ and tagged <name>:local.
IMAGES=(samba-ad workstation bind9 kea ansible freeradius-ad squid-ad)

usage() {
    cat <<'EOF'
Usage:
  eit.sh build [image...]        Build custom images (default: all)
  eit.sh up <lab> [args...]      Deploy a lab (docker compose up -d)
  eit.sh down <lab> [args...]    Tear a lab down (add -v to wipe its volumes)
  eit.sh ps <lab>                Show a lab's containers
  eit.sh logs <lab> [service]    Follow a lab's logs
  eit.sh exec <lab> <container> [cmd...]   Run a command in a container (default: bash)
  eit.sh list                    List available labs
  eit.sh help

Notes:
  - <lab> may be a number (1, 01, 5) or the full dir name (05-dns-deep-dive).
  - Containers use fixed role names (dc1, admin-ws, dns1, mail1, ...); `exec`
    targets them directly via `docker exec`.
  - Build the images once with `eit.sh build` before the first `up`.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Resolve a lab argument (number or dir name) to its labs/<dir> path.
resolve_lab_dir() {
    local arg="${1:-}"
    [[ -n "$arg" ]] || die "no lab specified (e.g. eit.sh up 01)"

    # Already a full directory name?
    if [[ -d "labs/$arg" ]]; then
        printf 'labs/%s\n' "$arg"
        return 0
    fi

    # Numeric: zero-pad to two digits and glob for labs/NN-*.
    local num matches
    num=$(printf '%02d' "$((10#$arg))" 2>/dev/null) || die "unknown lab: $arg"
    matches=(labs/"$num"-*/)
    if [[ -d "${matches[0]}" ]]; then
        printf '%s\n' "${matches[0]%/}"
        return 0
    fi

    die "unknown lab: $arg (try 'eit.sh list')"
}

# Echo the -f arguments needed to compose a lab.
compose_files() {
    local dir="$1"
    if [[ -f "$dir/docker-compose.yml" ]]; then
        # Standalone lab (Lab 01) — defines its own network.
        printf -- '-f\n%s/docker-compose.yml\n' "$dir"
    elif [[ -f "$dir/docker-compose.override.yml" ]]; then
        # Override lab — layered on the base network.
        printf -- '-f\nbase/docker-compose.yml\n-f\n%s/docker-compose.override.yml\n' "$dir"
    else
        die "no compose file found in $dir"
    fi
}

cmd_build() {
    local targets=("$@")
    [[ ${#targets[@]} -gt 0 ]] || targets=("${IMAGES[@]}")
    local img
    for img in "${targets[@]}"; do
        [[ -d "images/$img" ]] || die "no image context at images/$img"
        echo ">> building $img:local"
        docker build -t "$img:local" "images/$img/"
    done
}

cmd_up() {
    local dir; dir="$(resolve_lab_dir "${1:-}")"; shift || true
    mapfile -t files < <(compose_files "$dir")
    echo ">> up: $dir"
    docker compose "${files[@]}" up -d "$@"
}

cmd_down() {
    local dir; dir="$(resolve_lab_dir "${1:-}")"; shift || true
    mapfile -t files < <(compose_files "$dir")
    echo ">> down: $dir"
    docker compose "${files[@]}" down "$@"
}

cmd_ps() {
    local dir; dir="$(resolve_lab_dir "${1:-}")"
    mapfile -t files < <(compose_files "$dir")
    docker compose "${files[@]}" ps
}

cmd_logs() {
    local dir; dir="$(resolve_lab_dir "${1:-}")"; shift || true
    mapfile -t files < <(compose_files "$dir")
    docker compose "${files[@]}" logs -f "$@"
}

cmd_exec() {
    local dir; dir="$(resolve_lab_dir "${1:-}")"; shift || true
    local container="${1:-}"; shift || true
    [[ -n "$container" ]] || die "no container specified (e.g. eit.sh exec 01 dc1)"
    if [[ $# -eq 0 ]]; then
        docker exec -it "$container" bash
    else
        docker exec -it "$container" "$@"
    fi
}

cmd_list() {
    local d
    for d in labs/*/; do
        [[ -f "$d/docker-compose.yml" || -f "$d/docker-compose.override.yml" ]] || continue
        printf '%s\n' "$(basename "$d")"
    done
}

main() {
    local sub="${1:-help}"; shift || true
    case "$sub" in
        build)        cmd_build "$@" ;;
        up|deploy)    cmd_up "$@" ;;
        down|destroy) cmd_down "$@" ;;
        ps|status)    cmd_ps "$@" ;;
        logs)         cmd_logs "$@" ;;
        exec|sh|bash) cmd_exec "$@" ;;
        list|labs)    cmd_list ;;
        help|-h|--help) usage ;;
        *) usage; die "unknown command: $sub" ;;
    esac
}

main "$@"
