# Playbook: e2e-setup — a trustworthy end-to-end test gate

## Purpose
Set up an end-to-end (e2e) test suite that verifies the whole running system *through the app*
(browser / API), not one module — and that is trustworthy enough to be the per-PR gate. Pairs with
`playbooks/dev-local-setup.md` (a reproducible local stack) and `playbooks/pr.md` (the
verify-before-ship loop).

## When to use
A repo has no e2e (or weak e2e) and you want system-level tests that span the whole app: "set up
e2e", "add end-to-end tests", "scaffold a test gate".

## Where it lives
- **Unit/integration tests** stay inside each app/package — they own one module.
- **System e2e** is a dedicated top-level package (e.g. `e2e/`) — it spans all apps, so it belongs
  to none. Add it to the workspace if a monorepo.

## Procedure

1. **Stand the app up reproducibly.** Use `playbooks/dev-local-setup.md`. The e2e suite **never
   boots the app itself** — it runs against the already-running stack.

2. **Pick the framework that fits.** Playwright for browser flows; your HTTP client for API flows.
   Turn on **video + trace** — the recording is the proof, and it is gitignored output.

3. **Explore the flow live first** (don't guess selectors), then crystallize it into a committed
   spec.

4. **Keep the gate small and deterministic** — a handful of critical journeys. Each new feature PR
   adds its spec, so the suite compounds over time.

5. **Apply the practices that make e2e trustworthy:**
   - **Real flow, not bypass.** Drive the genuine path. For email codes / OTP, read the real code
     from a local mail server (Mailpit / Inbucket / MailHog) — never hardcode a fixed test code.
     That is what makes it a test, not a rehearsal.
   - **Verify auth ITSELF once; bypass it everywhere else.** A dedicated signup/login spec proves
     auth works. Every *other* spec shouldn't re-pay the login tax — build a **session helper**
     that mints an authed state once (real flow → saved storage state, or a service-role/token
     mint) and load it.
   - **Layered assertions: client → server → product.** Don't stop at "the UI changed." Confirm
     the server agrees (token validates / row/state is right) AND the user-visible outcome (e.g.
     plan upgraded *and* credits granted).
   - **Stable selectors.** Prefer role/label/text; add a small `data-testid` in the component when
     there is no good handle — never a brittle CSS path.
   - **Fresh data per run.** Unique emails/ids so reruns don't collide; mind rate limits (auth
     email, etc.).
   - **Commit specs + helpers, never `test-results/`** (generated output) — add it to
     `.gitignore`.

6. **Handle external services safely** (payments, email, 3rd-party). Use the vendor's
   **test/sandbox mode**, never live keys — and **guard hard**: the test should refuse to run if it
   detects a live key/credential. If a webhook completes the flow, forward it locally (e.g. the
   vendor's CLI listener) so the e2e exercises the real fulfilment path, not a faked event.

7. **When a test fails, triage before "fixing."** A red e2e is information. Classify first:
   - **Real bug** — the product broke. Fix the code; the test did its job.
   - **Stale test** — the flow intentionally changed (renamed route, new step). Update the test to
     match the new contract.
   - **Flaky / env** — stack down, timing, rate limit, stale data. Fix robustness/env.

   **Never weaken or delete an assertion just to go green.** Loosening is only correct when the
   *intended contract* changed — confirmed from the diff, not assumed.

## Success criteria
- An e2e suite lives in its own top-level package (e.g. `e2e/`) and runs against the
  already-running stack — it never boots the app itself.
- Video + trace evidence is enabled, and generated output (`test-results/`) is gitignored.
- A reusable auth/session helper exists; auth is verified directly in one spec and bypassed
  elsewhere.
- Critical-journey specs are committed, deterministic, use stable selectors and fresh per-run
  data, and assert across client → server → product.
- External services run in sandbox/test mode only, with a hard guard against live credentials.
- The suite passes against the local stack and is wired in as a per-PR gate.
