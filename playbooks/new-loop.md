# Playbook: new-loop — spin up a new loop (domain)

## Purpose
Stand up a new **loop** (a `domain`): a recurring thread of work an agent owns — a charter, a
cadence, and the artifacts it produces. This playbook creates one, proves it works with a single
real run, and leaves behind a `loops/domains/<loop>/README.md` that is the loop's live state.

Read `loops/ARCHITECTURE.md` first if you haven't — it is the model this playbook instantiates.
`loops/BOUNDARY.md` pins one home per concept; consult it before filing anything.

## When to use
The user wants to stand up a new workstream / beat / job (e.g. "a weekly SEO loop", "a support
triage loop", "a competitor-watch loop"). Do **not** use this for a one-off task — that is just a
backlog line in an existing domain, or a `doc` / `signal`.

## Inputs to gather (ask only what's missing)
Pull these from the request; ask a short clarifying round only for what you cannot infer. If the
request is already specific, infer all five and just confirm in your summary — don't interrogate.

1. **name** — kebab-case, the loop's home folder (`loops/domains/<name>/`). Keep it short.
2. **goal** — one line: the outcome this loop drives.
3. **cadence** — `manual` / `daily` / `weekly` / a cron expression. Default `manual`.
4. **what it does** — what the loop consumes (signals? data? an inbox? a URL?) and produces
   (signals? docs? a report? code changes via the ship-change procedure?).
5. **tools/data** — any sources or credentials it needs. Note them; point at a setup playbook or
   a `.env` file rather than inlining secrets.

## Procedure

1. **Ensure the substrate exists.** From the repo root, make sure these exist (create the folder
   and copy the schema `README` from the kit if missing — don't recreate one that's already
   there):
   - `loops/signals/README.md`, `loops/docs/README.md` — the two starter kinds.
   - `loops/domains/README.md` — the domain schema.
   - `loops/LOG.md` — the global feed (with its header/grammar).

   Do **not** pre-create a `tasks/` folder or any other kind. Earn those later per
   `loops/ARCHITECTURE.md`.

2. **Scaffold the loop README.** Create `loops/domains/<name>/README.md` from the template in
   `loops/domains/README.md`, filled with the gathered inputs. Required sections: frontmatter
   (`kind: domain`, `domain`, `status: active`, `goal`, `cadence`), a 2-4 line description,
   `## Current focus`, `## Backlog` (the loop's to-dos inline — these stay in the README until
   they earn a `task` kind), and an empty `## Timeline`. Add `## Evidence & analysis` and
   `## Metrics` placeholders if relevant.

   Check for collisions: if `loops/domains/<name>/` already exists, stop and ask whether to update
   it instead of overwriting.

3. **Do ONE real test run.** This is the point of the playbook: prove the loop actually runs, not
   just that the folder exists.
   - **Actually run the loop once, at small scale** — do whatever the loop is meant to do (triage
     a few real tickets, pull one real SERP, fetch the inbox, draft one comment, run one analysis
     query, scope one code change, …). Use the loop's real tools/data where you can; if a
     credential is missing, do the furthest-reachable dry run and note the gap.
   - **Producing an artifact is optional.** A legitimate run may surface nothing worth filing —
     that is a real result, not a failure. Only create a `signal` / `doc` if the run genuinely
     produced one.
   - Whatever happens, the run has two **required** outputs:
     - Append one dated line to the loop README's `## Timeline`:
       `YYYY-MM-DD | test run — <what you did and what you found / "nothing actionable yet">`.
     - Append one entry to `loops/LOG.md` using its grammar:
       ```
       ## YYYY-MM-DD · <loop-name> loop created + first run · #ops
       What: <one line — what the loop is and what the first run did/found>.
       Refs: loops/domains/<name>/README.md (new)[, any artifact created].
       ```

4. **Report back.** Summarize: the loop's charter (the five inputs), what the test run did and
   found, any artifacts created (or "none — nothing actionable this run"), any missing
   tools/credentials to wire up, and how to run it again (the cadence + the entry point). Keep it
   tight.

## Success criteria
- `loops/domains/<name>/README.md` exists with the required frontmatter and sections, filled from
  the gathered charter (no template placeholders left behind).
- The starter substrate (`loops/signals/`, `loops/docs/`, `loops/domains/`, `loops/LOG.md`) is
  present; nothing extra (no premature `tasks/` kind) was created.
- A real test run actually executed once — with a dated `## Timeline` line in the loop README and
  a matching `loops/LOG.md` entry — and any artifact it produced (if any) is filed in the right
  kind folder.
- The user has a clear summary: charter, run result, gaps, and how to re-run.

## Notes
- **Don't gold-plate the scaffold.** A loop README is live state, not a spec — start lean and let
  it accrete via its Timeline.
- **One loop = one separable workstream.** If what the user described is really part of an
  existing loop, say so and add it there (a backlog line + a `domain:` tag) instead of creating a
  near-duplicate domain.
- For loops that ship code, the loop's "run" can drive the ship-change procedure (see
  `playbooks/ship-change.md`) — point the README's Backlog at it.
