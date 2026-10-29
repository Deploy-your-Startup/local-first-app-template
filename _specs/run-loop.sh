#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

FILE="${TMPDIR:-/tmp}/local-first-checks.log"
RUNS="${1:-4}"

for ((i = 1; i <= RUNS; i++)); do
  echo "=== OpenCode slice $i/$RUNS ==="

  npx -y @opencode/cli run 'Implement the next incomplete vertical slice from
@_specs/todo.md using @_specs/local-first-app-template-plan.md.
Resolve slice 0 prerequisites first; do not invent approvals.
Owner scope decisions A1–A9 are resolved. The existing template repository is
the current repository (projects/tooling/local-first-app-template in the Factory
workspace), with its own origin and main branch.
Implement and commit template code and _specs here, not in the Factory parent repository.
Slice 1 is the last completed slice. Slice 2 (iOS) was rolled back and is the
next incomplete slice; historical Slice 2 evidence is not current completion.
The Factory slice-0-extraction-boundary branch is NOT a template PR predecessor;
the first template implementation PR targets main. Preserve its existing LICENSE.
Before implementation, verify GitHub push/PR access for the template repository.
Historical viewerPermission checks reported READ, then MAINTAIN. Verify current
access; stop if publishing is blocked. Do not create a fork or another remote
without owner approval.
Use the task list and @_specs/scratchpad.md as your only cross-run memory;
create the scratchpad if missing. Preserve existing work.

Implement only one slice, run its lint and tests, then commit, push and create
a stacked GitHub PR with gh. Target the previous slice branch, or the default
branch for the first slice. Include what changed, test results and how to validate.
Do not merge or force-push. Update the task list and scratchpad and stop.

Create/update _specs/checks.sh to run the actual checks for the active slice,
using explicit repository paths and existing make.sh/mise commands. Include
template rendering, lint, integration, browser E2E and native checks as applicable.
Propagate failures; never substitute placeholder checks or silently skip required
tests. Keep the PR draft if validation is incomplete.' || exit 1

  while true; do
    echo '=== Running checks ==='
    if bash _specs/checks.sh > "$FILE" 2>&1; then
      cat "$FILE"
      echo '=== All checks passed ==='
      break
    fi
    cat "$FILE"

    npx -y @opencode/cli run "The current slice from @_specs/todo.md failed validation.
Read @_specs/local-first-app-template-plan.md, @_specs/scratchpad.md and @$FILE.
Fix only the current slice. Do not weaken or bypass tests, lint or required behavior.
Run the checks, commit and push fixes to the existing stacked PR branch.
Update the PR validation evidence, task list and scratchpad, then stop.
Use the task list and scratchpad as your only cross-run memory." || exit 1
  done
done
