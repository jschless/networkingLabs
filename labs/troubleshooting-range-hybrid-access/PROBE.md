# Feature Probe Record — `troubleshooting-range-hybrid-access`

## Scope and decision

- **Feature and objective:** prove that the exact local Linux image supports
  dual-stack runtime addressing, local application service, runtime
  ip6tables denial, rule removal, and restored service without container
  restart.
- **Decision:** go with a client-command fallback; no rename.
- **Reason and fidelity statement:** the image's Python, IPv6, and nftables
  compatibility path passed. `curl` is absent, so range probes use Python's
  standard-library socket client. This remains a live Linux/network-policy
  model and makes no public-cloud product claim.
- **Owner and date:** Codex, 2026-07-29 UTC.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux x86_64, `5.15.0-181-generic #191-Ubuntu` |
| ContainerLab | 0.74.1, commit `1866b3a2b`, 2026-03-15 |
| Docker | client/server 29.5.3 |
| Host Python | 3.10.12 |
| Service image | `ops-lab:local`, ID `sha256:5e52cd20a7a61d16709a699b647f7fa32d119de3e35b766e28d83d4f170a812a`, 68,761,238 bytes |
| In-image versions | Alpine Linux 3.20; Python 3.12.12; iptables/ip6tables 1.8.10 (`nf_tables`) |
| Host resources before probe | 15 GiB RAM total, 12 GiB available, 0 B swap used; 139 GiB filesystem available |

## Smallest load-bearing test

The first disposable one-container command used `curl`; all setup commands
succeeded, but the client failed with exit 127 because the image intentionally
does not include curl:

```text
docker run --rm --name range-hybrid-access-probe --cap-add NET_ADMIN \
  ops-lab:local sh -lc '<IPv6 address + HTTP server + ip6tables test using curl>'

sh: curl: not found
Command exited with non-zero status 127
Elapsed: 5.47 s; maximum RSS: 29,992 KiB
```

The bounded fallback kept the same image and replaced only the client with
Python `socket.create_connection`:

```text
/usr/bin/time -v docker run --rm --name range-hybrid-access-probe \
  --cap-add NET_ADMIN ops-lab:local sh -lc '
    ip -6 addr add 2001:db8:ffff::1/128 dev lo
    python3 -m http.server 18080 --bind ::1 &
    python3 -c "<connect, request, require HTTP 200>"
    ip6tables -I OUTPUT -o lo -p tcp --dport 18080 -j REJECT
    # Python connection must fail.
    ip6tables -D OUTPUT -o lo -p tcp --dport 18080 -j REJECT
    python3 -c "<connect, request, require HTTP 200>"
  '

PROBE_PASS dual_stack_http_runtime_policy_clear_no_restart
Elapsed: 2.57 s; maximum RSS: 29,864 KiB; exit 0
```

The readiness retry emitted one expected initial `ConnectionRefusedError`
before the background server accepted connections; the subsequent pre-fault
and post-clear assertions passed.

## Cleanup and repeatability

- Both probe commands used `docker run --rm`; `range-hybrid-access-probe` was
  absent from `docker ps -a` after each run.
- No topology, network namespace, ContainerLab network, or host route was
  created.
- The successful command itself covered create, fault, clear, recovered
  request, process exit, and automatic container removal.

## Unsupported behavior and fallback

`curl` syntax is not a supported assumption for `ops-lab:local`. The
repository-local `http_probe.py` uses only Python 3.12 standard-library
modules. No mock, product substitution, or topology rename was required.
