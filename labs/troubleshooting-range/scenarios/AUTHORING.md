# Troubleshooting Range Scenario Contract

This contract extends [the networking-lab authoring guide](../../AUTHORING.md).
Unlike a normal lab, a range scenario is an assessment artifact: the engineer
receives a symptom, not a task or solution.

## Required directory layout

```text
scenarios/t<tier>-<slug>/
  metadata.env
  ticket.md                 # engineer-facing; never states cause
  inject.sh                 # introduces fault and proves symptom
  clear.sh                  # idempotently removes the fault
  verify.sh                 # proves real recovery, not a symptom mask
  rubric.md                 # proctor-only root cause and scorecard
```

`metadata.env` must provide `tier`, `domain`, `estimated_time`,
`topology_version`, and `parameterization`. Scenarios pin the topology version
they were tested against. A changed topology requires a new dry run.

## Fault and reset rules

- Injectors may mutate only runtime state or writable in-container copies.
  Never edit a bind-mounted repository file.
- `inject.sh` must fail unless it proves the reported symptom from the affected
  perspective.
- `clear.sh` must be safe to run twice.
- `verify.sh` must test the actual service path. A static route, host-file
  entry, or unrelated workaround that hides the original defect must fail.
- A scenario may not require container restart. If it exposes state that the
  generic reset cannot clear, its `clear.sh` must clean it explicitly.

## Ticket rules

Tickets describe impact, reporter, and observable symptom. They never name the
faulted node, protocol, command, or underlying cause. Include only the sort of
information a helpdesk escalation would normally have.

## Rubric template

Every rubric contains:

- root cause and pass threshold;
- tier time band;
- diagnostic decision tree / evidence milestones;
- point weight and deduction for every milestone;
- red flags, including shotgun changes and lack of verification;
- a clear statement that the scenario verifier is required for a pass.

## Definition of done

For every authoring change, perform and record this live dry run:

1. `./range.sh status` is green.
2. `./range.sh start <scenario>` injects and proves the ticket symptom.
3. Follow the rubric’s diagnostic path yourself; each claimed evidence command
   must actually establish its deduction.
4. Apply the minimal repair and run `verify.sh` successfully.
5. Run `./range.sh reset`; the health gate must return green without restart.

Use an isolated branch for each scenario directory. `range.sh`, the catalog
table, and docs registration are shared files and need a single owner.
