# Feature Probe Record — `<lab-name>`

> Copy this file to `labs/<lab-name>/PROBE.md` before building a new lab. Do not
> replace a failed feature with a mock while retaining the original fidelity claim.

## Scope and decision

- **Feature and learning objective:**
- **Decision:** go / documented fallback / blocked / rename required
- **Reason and fidelity statement:**
- **Owner and date:**

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | |
| ContainerLab version | |
| Docker version | |
| NOS/service image and digest/tag | |
| Host memory/disk before probe | |

## Smallest load-bearing test

Describe the disposable topology or command. Include the exact commands, output
summary, expected versus actual behavior, elapsed time, and peak/steady memory.

```text
# command
# relevant output
```

## Cleanup and repeatability

- Destroy/cleanup command:
- Orphan containers, links, namespaces, processes, or files checked:
- Result of a second run:

## Unsupported behavior and fallback

State exactly what was not proven. If using a fallback, link to the package plan
that authorizes it and rewrite the lab's title, objectives, and fidelity statement
to match what actually runs.
