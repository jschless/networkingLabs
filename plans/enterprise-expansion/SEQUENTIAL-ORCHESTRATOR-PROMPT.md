# Sequential Enterprise Lab Build Orchestrator Prompt

Copy this entire file into a coordinator task. It is intentionally an orchestrator
prompt: the coordinator creates one visible worker task at a time, waits for it to
finish, reconciles its PR, and only then starts the next item.

---

You are the implementation coordinator for the advanced enterprise network
engineering expansion in `/home/joe/containerlab`.

## Configuration

Treat these values as controlling instructions:

```text
BASE_BRANCH=main
BRANCH_PREFIX=codex/
MAX_ACTIVE_WORKERS=1
MAX_ACTIVE_LAB_RUNTIMES=1
MERGE_POLICY=AUTO_AFTER_GREEN
CONTINUE_AFTER_BLOCKED_ITEM=true
RUN_ASSESSMENT_RANGES=true
RUN_ASSESSMENT_TICKETS=true
```

`MERGE_POLICY=AUTO_AFTER_GREEN` explicitly authorizes you to enable guarded squash
auto-merge for PRs created by this program, but only after the acceptance gates in
this prompt pass. It does not authorize bypassing branch protection, dismissing a
review, overriding CI, force-pushing `main`, or merging an unrelated change.

If I change the value to `HUMAN_REVIEW`, create the PR and stop the entire queue at
that PR. Do not create another implementation task until the PR is merged into
`main`. Branch stacking and multiple open lab PRs with conflicting shared-doc edits
are not acceptable substitutes.

## Objective

Implement the expansion described by:

1. `PLAN-enterprise-network-engineering-expansion.md`
2. The assigned file under `plans/enterprise-expansion/`
3. `.claude/skills/new-lab/SKILL.md`
4. `labs/AUTHORING.md`
5. `docs/contributing.md`
6. For assessment ranges or tickets,
   `labs/troubleshooting-range/scenarios/AUTHORING.md` and the installed
   `troubleshooting-range-ticket-authoring` skill

Read each applicable instruction file completely before acting. The master plan and
the assigned work package define scope and fidelity. Current repository conventions
win where older skill text differs: use `topology.clab.yml` and document student
operations through `./scripts/lab.sh`.

The terminal outcome is a sequence of small, reviewable PRs in which every lab has
its own branch and PR, every lab was tested from a clean state, and no two lab
runtimes or worker tasks were active at once.

## Startup preflight

Before creating a worker task, verify all of the following:

- task/thread create, read, and wait capabilities are available (for example,
  `create_thread`, `read_thread`, and `wait_threads`);
- GitHub CLI or equivalent PR tooling is authenticated for push and PR creation;
- when `MERGE_POLICY=AUTO_AFTER_GREEN`, repository auto-merge is available or direct
  squash merge is permitted after required checks;
- Docker and Containerlab are reachable;
- the master plan, all 16 work-package plans, and this orchestrator prompt are
  committed and present on `origin/main`.

If the planning bundle is not yet on `origin/main`, stop before implementation and
report that it needs one planning-only PR. Do not copy uncommitted planning files into
individual worker branches; every worker must receive the same reviewed source of
truth from its base commit.

## Non-negotiable scheduling rules

1. Act as a coordinator. Do not implement a lab in the coordinator task.
2. Create exactly one visible worker task/thread for the current queue item. Do not
   spawn parallel subagents for implementation, testing, documentation, review, or
   ticket authoring.
3. Wait for that worker to reach a terminal result and for its lab runtime to be
   destroyed before creating the next worker task.
4. At most one `containerlab deploy`, range runtime, image build for this program, or
   live lab test may be active on the machine at any time.
5. Documentation lint and static checks may run only when the active worker is not
   performing a live deploy/test. Simplicity is preferred over overlapping jobs.
6. Never launch all queue items in advance. A created-but-waiting worker still counts
   as active.
7. Do not use broad cleanup such as deleting all containers, networks, worktrees, or
   lab directories. Resolve and destroy only the exact current lab resources.
8. Preserve all pre-existing user work, especially untracked content under
   `labs/opnsense-ngfw-basics/`. Do not add, remove, reformat, or claim it.

Before starting or resuming an item, reconcile reality rather than relying on memory:

- fetch `origin/main` without modifying user work;
- inspect existing program branches and open/merged PRs;
- inspect active Docker/Containerlab resources;
- inspect the current worker-task state;
- derive completed items from merged PRs and paths present on `origin/main`;
- detect a prior blocked item from its task result or draft PR.

If an unrelated lab runtime is active, do not stop it. Wait and report the collision.

## Queue and dependency order

Process this queue in order. A row may start only when all prerequisite rows are
merged into `main`. Evidence packs named by a work package travel with their parent
lab PR; they are not separate live-test tasks.

| Order | Queue item / branch suffix | Work-package plan | Prerequisites |
|---:|---|---|---|
| 0 | `enterprise-coverage-foundation` | Master plan, Phase 0 | None |
| 1 | `lab-cloud-hybrid-networking` | `01-cloud-hybrid-networking.md` | 0 |
| 2 | `lab-dci-evpn-multisite` | `03-dci-evpn-multisite.md` | 0 |
| 3 | `lab-wireless-core-operations` | `02-wireless-core-operations.md` | 0 |
| 4 | `lab-carrier-ethernet-handoff` | `04-carrier-cross-connects.md` | 0 |
| 5 | `lab-private-5g-enterprise` | `05-private-5g-enterprise.md`, Lab A only | 0 |
| 6 | `lab-mobile-transport-timing` | `05-private-5g-enterprise.md`, Lab B only | 5 |
| 7 | `lab-zero-trust-secure-access` | `06-zero-trust-secure-access.md` | 0 |
| 8 | `lab-internet-peering-ixp` | `07-internet-peering-ixp.md` | 0 |
| 9 | `lab-enterprise-dual-stack-capstone` | `08-enterprise-dual-stack-capstone.md` | 0 |
| 10 | `lab-sdwan-operations` | `13-sdwan-operations.md` | 1, 9 |
| 11 | `lab-global-application-delivery` | `15-global-application-delivery.md` | 1, 9 |
| 12 | `lab-enterprise-voice-sip-qos` | `09-enterprise-voice-sip-qos.md` | 0 |
| 13 | `lab-ot-zone-conduit` | `10-ot-zone-conduit.md` | 0 |
| 14 | `lab-dc-storage-networking` | `11-dc-storage-networking.md` | 2 |
| 15 | `lab-advanced-security-architecture` | `14-advanced-security-architecture.md` | 1, 7, 8, 9 |
| 16 | `lab-network-gitops-change-pipeline` | `12-network-gitops-change-pipeline.md` | 1, 2, 9 |
| 17 | `range-hybrid-access` | `16-assessment-ranges.md`, range A | 1, 3, 7, 9, 10, 11 |
| 18 | `range-dci-edge` | `16-assessment-ranges.md`, range B | 2, 4, 8, 14, 15 |
| 19 | `range-specialized-services` | `16-assessment-ranges.md`, range C | 5, 6, 12, 13 |

Queue item 0 is a foundation PR rather than a lab PR. Implement only the Phase 0
files in the master plan; do not begin a lab in the same branch.

For work package 13, use the lab name selected by its platform gate. If the supported
result is `orchestrated-wan-overlay`, use that honest name consistently in its branch,
directory, docs, coverage map, and PR title.

For queue items 17–19, the first PR for each range owns the topology, health gate,
golden reset, `range.sh`, catalog skeleton, and the required reference T1/T3 tickets.
After that range PR merges and its `topology_version` is frozen, derive the remaining
scenario list from work package 16. If `RUN_ASSESSMENT_TICKETS=true`, append one queue
item per remaining scenario and process those sequentially, with one scenario branch
and PR at a time. Never let scenario branches edit shared range files concurrently.

If `RUN_ASSESSMENT_RANGES=false`, stop after queue item 16. If ranges are enabled but
`RUN_ASSESSMENT_TICKETS=false`, stop after the three range foundation PRs and report
the remaining ticket queue.

## Per-item orchestration lifecycle

For each eligible queue item:

1. Confirm no worker task from this program is active and no lab runtime is active.
2. Confirm every prerequisite is merged and visible on `origin/main`.
3. Create one new visible task/thread with an isolated worktree based on the latest
   `origin/main`. Name it after the queue item.
4. Give the worker the complete worker prompt below with the item-specific fields
   filled in. Do not merely link to this coordinator prompt.
5. Wait for the worker. Use bounded status waits and continue waiting without asking
   me for routine input. Do not create another worker while it runs.
6. When the worker reports success, independently verify:
   - the PR exists and targets `main`;
   - its branch name matches `codex/<queue-item>`;
   - its diff is scoped to one lab/range/scenario plus required shared docs;
   - required checks and CI are green;
   - validation evidence and resource figures are in the PR or `VALIDATION.md`;
   - no current-lab containers/networks remain;
   - no unrelated user files were included.
7. Under `AUTO_AFTER_GREEN`, enable squash auto-merge or squash-merge the PR only
   after all required gates pass. Wait until GitHub reports it merged, fetch
   `origin/main`, and confirm the merge is present before continuing.
8. Under `HUMAN_REVIEW`, report the PR and stop the queue.
9. Record a compact coordinator status entry: queue item, task ID, branch, PR URL,
   probe decision, test result, merge SHA or blocker, and next eligible item.
10. Reconcile the queue again before creating the next worker.

Do not accept a worker's prose assertion in place of test evidence. Do not merge a
draft PR, a PR with failing/skipped required checks, or a PR whose live test ended
without a scoped destroy/cleanup.

## Worker prompt template

Supply this complete prompt to each worker, replacing bracketed fields:

---

You own exactly one implementation item in `/home/joe/containerlab`.

```text
QUEUE_ITEM=[queue item]
BRANCH=codex/[queue item]
PLAN=[absolute path to assigned work-package plan]
DELIVERABLE=[exact lab, range, foundation, or scenario name]
SCOPE_NOTE=[Lab A/Lab B/range/scenario boundary, or "entire assigned plan"]
BASE=origin/main
```

Work only on this item. Do not spawn subagents or other tasks. The coordinator is
serializing access to the lab host, so you must complete and clean up this item before
returning.

Before acting, completely read:

1. `PLAN-enterprise-network-engineering-expansion.md`
2. `[PLAN]`
3. `.claude/skills/new-lab/SKILL.md` and the references it requires for the selected NOS
4. `labs/AUTHORING.md`
5. `docs/contributing.md`
6. For a range/scenario, `labs/troubleshooting-range/scenarios/AUTHORING.md` and the
   installed `troubleshooting-range-ticket-authoring` skill

Inspect `git status` before editing. Preserve pre-existing and unrelated changes,
especially `labs/opnsense-ngfw-basics/`. Start `BRANCH` from the latest
`origin/main`; never base it on another unmerged implementation branch. If the
branch already exists, inspect its PR and continue it only if it clearly belongs to
this exact queue item.

### Required method

1. Perform the package's smallest load-bearing feature/platform probe before building
   the full topology. Record exact versions, commands, output, resource use, and the
   resulting go/fallback/rename decision in `PROBE.md` or the plan-required record.
2. Follow only the documented fallback when a feature is unavailable. Never retain a
   product or hardware-fidelity claim after substituting a mock. If no honest fallback
   meets the learning objective, stop as blocked with probe evidence.
3. Build the complete lab-builder file set, instructional task progression,
   symptom-led Break-It, mechanism observability, `check.sh`, docs wrapper, indexes,
   navigation, image documentation, coverage data, and package-specific artifacts.
4. Keep prebuilt addressing and plumbing separate from the feature students must
   configure. Guided work must be at most 20%; most tasks are hinted; at least one is
   open. Each core task follows Objective/Predict/Hints/collapsed Solution/Check.
5. Use pinned images and stay within the work package's resource/headroom target.
6. Test from a clean state, sequentially:
   - build required local images;
   - deploy and pass readiness gates;
   - perform the documented student path without treating source configs as an answer key;
   - run `check.sh` and all visible verification commands;
   - inject the Break-It and prove the intended assertion fails;
   - diagnose from documented evidence, apply the minimal repair, and prove checks pass;
   - destroy with the scoped lab cleanup;
   - redeploy and prove the initial state is repeatable;
   - destroy again and confirm no current-lab resources remain.
7. Record deploy time, peak and steady memory, exact image versions, limitations,
   test transcript summary, and cleanup result in `VALIDATION.md` or the prescribed
   validation record.
8. Run all repository and package gates, including:

   ```bash
   python3 scripts/lint-labs.py
   ./scripts/check-docs-admonitions.sh
   mkdocs build --strict
   shellcheck -S warning scripts/*.sh labs/*/check.sh
   ```

   Scope extra checks to the current deliverable. Do not run another live lab while
   the current lab is deployed.
9. Review the final diff for accidental generated files, secrets, credentials,
   captures with sensitive data, runtime state, unrelated edits, and mutable image tags.
10. Commit, push, and create one PR targeting `main`. Use a title beginning with the
    deliverable name. Do not merge it yourself.

### PR acceptance evidence

The PR body must include:

- assigned plan and coverage target;
- probe result and exact versions;
- topology and fidelity summary;
- files and shared registrations changed;
- clean deploy/check/break/fix/redeploy/destroy results;
- positive and negative validation results;
- peak/steady memory and deploy time;
- repository validator results;
- unsupported or evidence-only behavior;
- rollback/cleanup statement;
- follow-ups that are explicitly not represented as complete.

Return only after the PR exists and the current lab is destroyed. Your final result
must state branch, commit, PR URL, test summary, resource figures, cleanup result, and
any blocker. If blocked, do not create a misleading completed-lab PR; a narrowly
scoped draft probe PR is acceptable when it preserves useful, validated evidence.

---

## Blocker behavior

Do not ask me routine design questions. Make the bounded choices already authorized
by the plans and record them. A real blocker is one of:

- missing image/license/credential that cannot be replaced by the documented fallback;
- unsupported host/kernel behavior with no honest fallback;
- unrelated active runtime that prevents exclusive testing;
- inability to push/create or safely merge a PR;
- failing branch protection or CI that requires external action;
- a scope conflict with existing user work.

A worker must attempt safe diagnosis, cleanup, and documented fallbacks before
declaring a blocker. On a blocker it must leave no lab runtime active and return exact
evidence and the smallest required human action.

If `CONTINUE_AFTER_BLOCKED_ITEM=true`, mark that item blocked, skip every item that
depends on it, and continue with the next independent eligible row. Never pretend a
blocked prerequisite is complete. If false, stop the queue at the blocker.

## Coordinator reporting and terminal condition

Keep status concise but durable in this coordinator task. After each item report:

```text
[queue item] — merged | awaiting human review | blocked | skipped dependency
worker: <task id>
branch: <branch>
PR: <URL>
probe: <go/fallback/rename/block>
live validation: <pass/fail/not run>
cleanup: <clean/problem>
next: <queue item or terminal reason>
```

Continue autonomously while there is an eligible queue item and the merge policy
permits it. Finish only when the selected queue is merged and validated, the queue is
waiting at a human-review PR, or no further item is eligible because of recorded
blockers. The final report must list merged PRs in queue order, blocked/skipped items,
remaining assessment tickets, and confirmation that no program lab runtime remains.
