# Playbook: ship-change — implement a scoped change end-to-end into a PR

## Purpose
Ship a focused code change end-to-end: create an isolated git worktree, implement the change,
simplify it, review and fix blocking issues, verify it locally, then open a pull request — opening
the PR **only if verification passes**. The worktree keeps the change off the user's main checkout
so parallel work doesn't collide.

This is the runtime-neutral writeup of the ship-change procedure. The phases below are normally run
in sequence; an orchestrator that can delegate each phase to a fresh, context-isolated worker may
do so, but a single agent running the phases in order satisfies the procedure just as well.

## When to use
A scoped change on an existing repo that should end in a PR. You know **what to build** (the task)
and **which repo** (an absolute path). Optional inputs: base branch (default `main`), a desired
branch name, verification hints, whether to actually open the PR, and whether to run the review
phase.

## Procedure

1. **Setup — create an isolated worktree.** Do this without disturbing the user's main checkout;
   only READ from the main checkout (for the env-file and dependency copy below).
   1. From the repo, run `git fetch origin --prune` (ignore failure if offline). Determine the
      freshest base ref: prefer `origin/<base>` if it exists, else local `<base>`.
   2. Pick the feature branch name (use the given one, else derive a short, kebab-case,
      conventional name from the task, e.g. `feat/<slug>` or `fix/<slug>`). Make sure it does not
      already exist (append `-2`, etc. if needed).
   3. Choose a worktree path **outside** the main checkout — a sibling dir like
      `<repo>-worktrees/<branch-slug>` (create the parent dir if needed). Avoid nesting inside the
      repo.
   4. Create it: `git -C <repo> worktree add <worktreePath> -b <branch> <baseRef>`.
   5. Verify: the worktree path exists, `git -C <worktreePath> rev-parse --abbrev-ref HEAD` shows
      the new branch, and `git -C <worktreePath> status` is clean.
   6. **Carry over gitignored local env files.** `git worktree add` only populates
      version-controlled files, so a fresh worktree has NO `.env` files and the app can't boot —
      this silently blocks later verification. List ignored files
      (`git -C <repo> ls-files --others --ignored --exclude-standard`), keep ONLY env files
      (basename matching `.env` or `.env.*`; filter with `grep -E '(^|/)\.env(\.[^/]+)?$'`), and
      copy each into the worktree preserving its relative path. Do NOT copy
      node_modules/dist/build/cache artifacts. They stay gitignored in the worktree — confirm none
      show up in `git -C <worktreePath> status`.
   7. **Warm the worktree's dependencies** so later phases can run typecheck/lint/tests (a fresh
      worktree has none). This step is ecosystem-specific:
      - If the base checkout has no installed dependencies, skip (later phases install on demand).
      - **Fast path (copy-on-write clone), preferred** where the filesystem supports it (e.g. APFS
        on macOS) AND the worktree's lockfile matches the base's: clone each top-level dependency
        dir into the worktree with a copy-on-write copy (`cp -c -R` on APFS — near-instant, no
        extra disk). Abandon to the fallback on any error.
      - **Fallback (install):** run the repo's package install in the worktree (the global package
        store is usually warm, so it is link-mostly). If installing is too heavy to be worth it,
        skip and let later phases install on demand.
      - For non-Node ecosystems, set up the environment on demand in later phases instead.
      - These dependency dirs stay gitignored — confirm `git -C <worktreePath> status` is still
        clean afterward.
   8. **Check whether the repo ships its own PR procedure** by testing for
      `<worktreePath>/.claude/skills/pr/SKILL.md` (or the repo's documented PR playbook, e.g.
      `playbooks/pr.md`). If it has one, the verify+PR phases below are **delegated** to it (it
      runs its own heavier, app-driving verification and only opens a PR once the feature is
      proven), so this playbook's own Verify phase is skipped.

   All later phases operate **inside the worktree**, never the original checkout.

2. **Implement.** Work only inside the worktree, on the feature branch. Do NOT commit yet — a later
   phase commits once.
   - Investigate first: read the relevant code, types, and call sites before editing. Confirm
     signatures/field names against the actual source — don't assume.
   - Make the change focused and idiomatic — match the surrounding code's conventions, naming, and
     comment density.
   - Prefer putting new pure/testable logic in its own module (free of framework/runtime-specific
     imports) and wiring it in, so it can be unit-tested in isolation.
   - Add or update tests for the new behavior where the repo has a test setup.
   - Respect any scope / out-of-scope boundaries in the task. Do not gold-plate. Leave a brief code
     comment for any deliberately deferred follow-up.
   - Sanity-check types/build on the changed area if it's fast (don't block on a slow full build).
     If you add or change a dependency, run the repo's install yourself.

3. **Simplify (quality pass — SIMPLIFY ONLY).** Do not hunt for bugs, do not change behavior, do
   not expand scope. Run `git --no-pager diff` in the worktree to see the exact changes, then
   improve ONLY the changed code for: reuse/dedup, simplification & readability, efficiency, and
   correct altitude (logic in the right module; entrypoints stay thin). Keep behavior identical. Do
   not commit.

4. **Review + fix (blocking issues only).** This phase wants an independent, rigorous look at the
   diff; an independent reviewer (a separate review tool or a fresh reviewer if your runtime
   supports one — an external code-review CLI such as Codex is a good second opinion when available
   and authenticated; otherwise do the review yourself, just as rigorously) examines the diff for
   BLOCKING problems: correctness bugs, runtime/environment incompatibilities, security holes
   (injection/escaping/authz), regressions to existing behavior, pathological regex/perf, and type
   errors. Ignore pure style nits (Simplify already ran). FIX every blocking issue you can confirm
   is real, editing files directly in the worktree. Do NOT commit. Do NOT expand scope. (This phase
   is optional and can be turned off when the change is trivial.)

5. **Verify locally** (skip if delegating to the repo's own PR procedure — see Setup step 8). Be
   rigorous and HONEST — report real command output; never claim success you didn't observe.
   1. Discover the right commands from the repo (`package.json` / `turbo.json` / `Makefile` /
      etc.). Prefer SCOPED, fast checks over full builds: type-check, lint on changed files, and
      the unit/integration tests that cover the changed code.
   2. Run them; capture pass/fail + key output for each.
   3. If something fails due to a real defect in the new code, apply a MINIMAL fix and re-run (a
      few iterations max). Do not expand scope. Do not commit.
   4. Honestly note anything that can't be checked locally (real production runtime, external
      services, manual UX).
   - Treat verification as passed ONLY if the relevant checks for the changed code pass.

6. **PR.** Behavior depends on the flags and Setup step 8:
   - **If not opening a PR:** stop after Verify. The changes sit in the worktree, uncommitted.
   - **If the repo ships its own PR procedure (delegated path):** review `git status` and
     `git --no-pager diff` so the commit includes only the intended files; commit with a clear
     Conventional Commit message (note any deliberate follow-ups/out-of-scope items); then follow
     the repo's own PR procedure exactly (it brings up the stack, has an independent reviewer drive
     the running app to verify the feature, runs the regression sweep, then opens the PR with
     proof). Do NOT open a PR yourself ahead of that — let that procedure gate it.
   - **Inline path (this playbook's Verify passed):** review `git status` and `git --no-pager diff`
     for stray files; commit the intended files with a clear Conventional Commit message;
     `git push -u origin <branch>`; open the PR (`gh pr create --base <base> --head <branch>`) with
     a clear title and a body covering what & why, the verification performed, and explicit
     out-of-scope/follow-ups.
   - **If Verify did NOT pass:** skip commit/PR. Leave the changes in the worktree for human
     review.
   - If `git push` or `gh` fails (auth/permissions), do NOT force anything — surface the failure
     reason so the human can finish it.

7. **Clean up the worktree.** After the PR is pushed (or once you've handed the worktree to the
   human), remove the worktree with `git worktree remove <path>` — a leftover worktree pins its
   branch. Confirm `git worktree list` shows no stray entries.

## Success criteria
- The change was made on an isolated feature branch in a worktree outside the main checkout; the
  user's main checkout was never modified.
- Gitignored env files were carried into the worktree so the app could boot for verification, and
  the worktree's `git status` stayed clean (no stray env/dependency files staged).
- The diff went through the Simplify pass and (when enabled) a blocking-issue Review with
  confirmed fixes applied.
- A PR is opened **only** when verification passed — either this playbook's local Verify, or the
  repo's own PR procedure when one exists; otherwise the change is left in the worktree for human
  review with the reason recorded.
- The commit is a clean Conventional Commit of only the intended files, and the worktree is removed
  at the end (no stray `git worktree list` entries).
