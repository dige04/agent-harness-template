# Playbook: pr — prove the feature works, then open the PR

## Purpose
Prove the feature you just built actually does what was intended — an **independent reviewer drives
the real app** — then open a pull request that leads with that proof. Never open a PR until the
feature is verified. Pairs with `playbooks/dev-local-setup.md` (reproducible stack) and
`playbooks/e2e-setup.md` (the suite).

You are the **orchestrator + fixer**. Verification splits by who is best at it:

- **The subjective question — "does the feature I just built do what was intended?"** → hand to an
  **independent reviewer** who drives the real app and judges it. Independence (the reviewer didn't
  write the code) and context-isolation (app-driving is verbose) pay off here. Use a fresh
  verifier sub-agent if your runtime supports spawning one; otherwise do this as a separate,
  deliberate review pass with fresh eyes. Most new features have no spec, so this is **agentic
  verification by driving the app, not just "run the test."** Do it first.
- **Objective, codified checks** (type-check, lint, unit, existing e2e) → **you** run them
  afterward as a regression sweep. Pass/fail can't be rubber-stamped, so delegating buys nothing
  but a round-trip — and you need the error to fix it.

## When to use
A change is ready to ship in any repo — "open a PR", "ship this", "raise a PR". Use it whenever a
just-built feature needs to be proven before it goes up for review.

## Procedure

1. **Preconditions.** You are on a branch (not the default branch); changes are committed.

2. **Bring up the stack — once.** Start it via the repo's dev launcher (see
   `playbooks/dev-local-setup.md`). You own it; the reviewer reuses the same running stack.

3. **Verify the FEATURE → fix → re-verify (loop).** Brief from the plan file if one exists (point
   the reviewer at it), else pass the requirements inline. Have an **independent reviewer** (a
   read-only verifier sub-agent if your runtime supports one; otherwise a separate review pass)
   confirm the feature by driving the running app. The reviewer must not edit code. Brief the
   reviewer with this shape:

   ```
   You are a read-only verifier. Do NOT edit code. Independently confirm THIS feature
   works by driving the running app (the stack is already up). It likely has no
   automated spec — verify it agentically.

   FEATURE (what a user should now be able to do, and the observable success state):
     <intent / acceptance criteria>          (or: see plan file <path>)
   HOW TO EXERCISE IT:
     <UI route + steps / API call / CLI>
   AUTH (if the feature is behind login):
     mint a session first via the repo's session helper and load it before driving.

   Drive it (browser via a browser-automation tool, or the API/CLI): walk the exact
   steps, screenshot/record the success state, judge observed vs expected. Return ONLY:

   FEATURE: works | broken
     expected: <criteria>
     observed: <what actually happened>
     evidence: <screenshot/video paths>
   ```

   - **broken** → fix the implementation, then run a **fresh** verification pass. You never declare
     the feature works yourself — an independent pass does.
   - Cap at ~3 rounds; if still broken, escalate to the human with the verdict.

4. **Regression sweep — you run the codified checks; fix red directly.** type-check · lint · unit ·
   existing e2e. Triage failures (real-bug vs stale-test — see `playbooks/e2e-setup.md`); never
   weaken an assertion to go green. If a fix here changes feature behavior, re-verify (step 3).

5. **Open the PR — lead with the feature proof.** Get a **reviewable link** for the success video.
   GitHub can't play video inline via automation, so upload it somewhere with a stable URL — a
   dedicated `pr-evidence` GitHub prerelease (`gh release upload`), a bucket, or CI artifacts — and
   link it.

   ```markdown
   ## What changed
   <1–3 lines>

   ## Feature verified ✅  (an independent reviewer drove the app)
   - <acceptance criteria> — observed working.  📹 Proof: <url>

   ## Regression guardrails
   - [x] type-check · lint · unit · e2e

   ## How to reproduce
   <stack-up command> && <exercise steps>
   ```

## Success criteria
- The feature was confirmed working by an **independent** pass that drove the real app (not
  self-review), with screenshot/video evidence captured.
- The codified regression checks (type-check, lint, unit, existing e2e) are green, with failures
  triaged honestly rather than assertions weakened.
- A PR is open on a branch (never the default branch), leading with the feature proof and a
  reviewable link to the success recording, plus reproduce steps.
- No PR was opened before the feature was verified — proof, not claims.

## Rules
- **The feature is the verdict** — a green suite with an unverified feature isn't done.
- **"Does it actually work" → an independent reviewer; objective checks → you.**
- Never open a PR until the feature is verified. **Proof, not claims.** Branch → PR only.

> Isolates *context*, not *environment*: if your stack is single-instance / fixed-port, don't run
> multiple verification passes against it in parallel.
