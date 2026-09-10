# Roadmap Execution Workflow

This file defines how automated agents and maintainers turn `docs/PRODUCT_ROADMAP.md` into repository changes.

## Before implementation

1. Read `AGENTS.md` and `docs/PRODUCT_ROADMAP.md` in full.
2. Identify the current active milestone and the smallest unfinished slice that matches the requested work.
3. Check whether the requested work is:
   - inside the current milestone;
   - a bug/security/CI/dependency interruption that may legitimately bypass sequencing; or
   - an explicit project-owner override.
4. Keep the proposed PR scoped to one roadmap slice or one tightly coupled set of slices from the same milestone.
5. For UI work, define concrete visual acceptance criteria before editing code.
6. For performance work, identify the observable/repeated cost that the change is intended to remove or measure.

## During implementation

- Preserve the authoritative filesystem model and action paths.
- Do not introduce later-milestone architecture preemptively.
- Prefer the smallest implementation that satisfies the current slice and its exit criteria.
- Keep UI polish consistent with the Zen direction and independent DiskUsage identity.
- Update EN/RU user-visible text together.
- Add focused regression coverage for correctness-sensitive behavior.

## Pull request

Use `.github/pull_request_template.md`.

The PR must identify its roadmap milestone/slice. If the change materially alters the roadmap, include the roadmap update in the same PR.

UI changes should include screenshots or equivalent concrete visual verification when practical. Performance changes should include measurement, profiling evidence, or a clear structural explanation of the repeated work removed.

## Milestone completion

A milestone is complete only when every stated exit criterion in `docs/PRODUCT_ROADMAP.md` is satisfied or explicitly waived by the project owner.

When completing a milestone:

1. Update the roadmap status/current milestone in the same PR that closes the final slice, or in an immediately following documentation-only PR if required by branch protection.
2. Record any intentionally deferred item in the next appropriate milestone instead of silently dropping it.
3. Do not start implementation of the next milestone until the roadmap reflects the transition.

## Exceptions

The project owner may explicitly reorder, skip, add, or immediately implement work outside the roadmap. Such an instruction overrides roadmap sequencing but does not override filesystem correctness, user safety, privacy, security, or release-integrity rules in `AGENTS.md`.

If an urgent bug, security issue, broken CI gate, or dependency/security maintenance item interrupts roadmap work, fix the interruption first and then resume the current milestone without silently advancing the roadmap.