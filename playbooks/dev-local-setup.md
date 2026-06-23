# Playbook: dev-local-setup — a one-command local launcher

## Purpose
Produce **one script** (`scripts/dev-local.sh`) that a person or agent runs to bring the whole
local stack up — every long-lived dev server in its own tmux window, plus any infra (DB, cache,
queues) the app needs — and a short doc so it stays discoverable later. The reproducible local
stack is the foundation the e2e gate and the verify-before-ship loop run against.

Do **not** start any dev servers yourself. You are *generating* the launcher, not running it.
Build it, syntax-check it, then hand it to the user to run.

## When to use
A repo has no one-command local launcher (or a flaky/ad-hoc one) and you want a single, idempotent
entry point to start it: "set up dev-local", "make a one-command dev launcher", "I want one script
to start this repo", "scaffold dev-local for this project".

## Procedure

1. **Investigate the repo (don't guess).** Discover the real facts before writing anything:
   - **Package manager & layout** — look for `pnpm-workspace.yaml` / `turbo.json` / `nx.json` /
     `lerna.json` (monorepo) or a single `package.json`, `Cargo.toml`, `go.mod`,
     `pyproject.toml`, `Makefile`, `Procfile`, `docker-compose.yml`.
   - **Services to run** — each app/package with a `dev`/`start`/`serve` script, each `Procfile`
     line, or each `docker-compose` service. Note the exact start command (e.g.
     `pnpm --filter <name> run dev`, `npm run dev`, `cargo run`, `uvicorn app:app --reload`).
   - **Ports** — grep configs and `.env` for the port each service binds (`PORT`, `listen(`,
     `server.port`, framework config like `rsbuild.config`, `vite.config`, `next.config`). Record
     which service talks to which.
   - **Infra dependencies** — does a backend need Postgres / Supabase / MySQL / Redis / Mongo /
     Kafka? Check `.env`(`.local`), ORM config, `docker-compose`, and connection-string defaults.
     Decide how to provide each locally (`supabase start`, a Docker container, an existing
     `docker-compose`).
   - **First-run setup** — migrations, seed, codegen, `install`. Note the commands but keep them
     OUT of the default `up` path (offer a separate subcommand).
   - **Env files** — confirm a committed `.env.example` / `.env`; never invent or print secrets.
     The script must not inject credentials.

   Write down a small table: service → command → port → depends-on. That table is the spec for the
   script.

2. **Generate `scripts/dev-local.sh`.** Adapt the skeleton in
   `playbooks/assets/dev-local.template.sh`. Fill in the discovered services, ports, and infra.
   Keep these invariants:
   - **One tmux session**, one window per long-lived server. Idempotent: re-running `up` leaves
     existing windows alone instead of duplicating them.
   - **Preflight** that fails fast with install hints when a required tool is missing (tmux, the
     package manager, Docker if infra needs it).
   - **Infra brought up before servers**, reused if already running.
   - Subcommands: `up`, `down` (and `down --all` to stop infra), `status` (window list + port
     check), `logs <name>`, `restart <name>`, `attach`, plus any project-specific one-shots
     (`migrate`, `seed`).
   - Resolve repo root from the script's own location so it works from any cwd.
   - No secrets in the script. Print URLs and a port check at the end of `up`.

   If the repo has **no infra needs**, drop the Docker/DB parts entirely — keep it to preflight +
   tmux windows. Match the script's complexity to the repo; simpler is better.

   Then make the script executable (`chmod +x scripts/dev-local.sh`) and syntax-check it
   (`bash -n scripts/dev-local.sh`). Verify the read-only `status` path runs cleanly. Do **not**
   run `up`.

3. **Write a short doc.** Create a discoverable doc for the launcher (e.g. a `dev-local` skill doc
   under your runtime's skills location, or a `docs/dev-local.md`) with: a trigger/summary line, a
   service/port table, prerequisites, the subcommand list, and brief troubleshooting (port-in-use,
   a window exited, infra not running). Keep it to one screen — it documents the script, it
   doesn't re-explain it.

4. **Hand off.** Tell the user the exact commands: `scripts/dev-local.sh up`, plus any first-run
   step (`… migrate`). List the URLs. Note any prerequisite they must install or start (e.g.
   Docker Desktop) before the first `up`.

## Success criteria
- `scripts/dev-local.sh` exists, is executable, passes `bash -n` cleanly, and its `status`
  subcommand runs without error.
- The script is idempotent (re-running `up` does not duplicate servers or clobber running infra)
  and resolves its own repo root.
- It contains no secrets and starts no servers during setup — you generated and syntax-checked it
  only.
- A short discoverable doc describes the services/ports, prerequisites, and subcommands.
- The user has the exact `up` command, any first-run step, the URLs, and any prerequisite to
  install.

## Principles
- **Discover, don't assume.** Ports and start commands come from the repo, never from convention
  alone.
- **Idempotent & safe to re-run.** No duplicate servers, no clobbered infra.
- **Right-sized.** A 3-service monorepo with Postgres+Redis needs the full skeleton; a single Vite
  app needs ~30 lines. Don't over-build.
- **Never run servers or print secrets.** Generate, syntax-check, hand off.
