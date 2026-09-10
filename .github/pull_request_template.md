## Summary

<!-- What changed and why? -->

## Roadmap alignment

Before implementation, follow `docs/agent/ROADMAP_WORKFLOW.md` together with `AGENTS.md` and `docs/PRODUCT_ROADMAP.md`.

- [ ] This PR belongs to the current milestone in `docs/PRODUCT_ROADMAP.md`, or the project owner explicitly authorized an exception.
- [ ] The PR does not mix unrelated roadmap milestones.
- [ ] If this PR completes, reorders, skips, or materially changes a milestone, `docs/PRODUCT_ROADMAP.md` is updated in the same PR.
- [ ] Any significant new product feature not already covered by the roadmap has been added to the roadmap or explicitly authorized by the project owner.

Roadmap milestone/slice: <!-- e.g. M1.2 -->

## Correctness and safety

- [ ] Filesystem semantics, allocated-size semantics, path identity, cancellation, and Trash-only behavior remain correct where applicable.
- [ ] No new telemetry, tracking, account, cloud, or background network behavior was introduced.

## UI / UX

- [ ] User-visible strings are localized in English and Russian where applicable.
- [ ] UI changes follow the Zen visual direction and remain recognizably independent from DaisyDisk or any other reference product.
- [ ] UI changes include screenshots or another concrete visual verification when practical.
- [ ] Keyboard/focus/accessibility and long-path/window-size behavior were considered where relevant.

## Performance

- [ ] No avoidable repeated whole-tree transformation, sorting, or visualization preparation was added to the main UI path.
- [ ] Performance claims are backed by measurement or by a direct structural removal of known repeated work.

## Verification

- [ ] Applicable tests/builds pass.
- [ ] Required security and repository policy checks pass.