# DBIO::Valiant Extraction — Design Spec

**Date:** 2026-07-09
**Branch of record:** `dbio-integration` (Valiant monorepo)
**Status:** Approved design, pending implementation plan

## Context

The Valiant distribution currently ships four namespaces from one repo, including two
parallel ORM-integration trees:

- `lib/DBIx/Class/Valiant/**` (+ `t/dbic/**`, `t/lib/{Example,Schema}/**`) — the original
  DBIx::Class integration, with deep history (134 commits touch `lib/DBIx/Class/Valiant*`,
  78 touch `t/dbic/`).
- `lib/DBIO/**` (+ `t/dbio/**`, `t/lib/{ExampleIO,SchemaIO}/**`, `t/lib/TestDBIO.pm`) — a
  straight copy-port to DBIO (async fork of DBIx::Class), added entirely on the
  `dbio-integration` branch (100% new; absent from `main`).

The recorded decision (dbio-integration-notes.md, 2026-07-08) is that **both** plugins are to
be extracted into their own distributions before any CPAN release; the monorepo branch was
the staging ground. This spec covers the **DBIO extraction first**; DBIx::Class extraction is
a later, identical cycle.

Current baseline: `prove -lr t` → **102 files / 2411 tests PASS**.

## Goals

- Extract DBIO into a standalone `DBIO::Valiant` distribution **without losing git history**.
- New dist mirrors Valiant's Dist::Zilla + dependency-management setup.
- New dist is green in isolation (real in-memory SQLite via `DBIO::SQLite`, no mocks).
- Published to GitHub as `jjn1056/DBIO-Valiant`.
- Core Valiant cleaned of the now-unneeded DBIO dependencies, still green.

## Non-goals (this cycle)

- Extracting DBIx::Class::Valiant (stays in core for now; separate later cycle).
- Any behavior change to either integration.
- CPAN upload (repo creation + green tests only; release is a separate step).
- Rewriting core Valiant's history (explicitly rejected — see Decisions).

## Decisions (settled with John)

1. **Land the branch by local fast-forward**: FF `main` → `dbio-integration`, push `main`.
   True linear FF (main is fully contained, branch is +38, zero divergence). PR #13
   auto-closes as merged. No merge commit; every SHA preserved.
2. **Core repo is cleaned by `git rm`, not history-rewrite.** Valiant is public/established;
   rewriting `main` would break every clone/PR. The removed plugin code remains in core's
   history; it is simply absent going forward.
3. **New GitHub repos:** `jjn1056/DBIO-Valiant` (this cycle) and `jjn1056/DBIx-Class-Valiant`
   (later), created on GitHub, public, Perl_5.
4. **DBIO first.** DBIx::Class follows once DBIO is proven end-to-end.
5. **Starting version** for `DBIO::Valiant`: **0.001001**.
6. **Mirror Valiant's Dist::Zilla setup** and dependency management in the new dist.

## Approach: `git-filter-repo`

`git-filter-repo` (installed at `/usr/local/bin/git-filter-repo`) on a **fresh clone**, keeping
only the DBIO paths. Alternatives considered and rejected:

- `git filter-branch` — deprecated, slow, error-prone.
- `git subtree split` — not installed here, and only handles a single directory prefix (can't
  combine `lib/` + `t/` paths in one pass).

filter-repo removes the `origin` remote by default (safety against pushing rewritten history
back to Valiant) — desirable here, since we push to a new remote.

## Detailed design

### Phase 1 — Land the branch

- Verify clean state; FF `main` to `dbio-integration`; `git push origin main`.
- Confirm PR #13 shows merged/closed.
- `main` is now the extraction source of truth.
- Do **not** `git add` the untracked root `CLAUDE.md` (project instructions, intentionally
  untracked). Any commit adds only explicitly named files — never `git add -A`.

### Phase 2 — Extract history

Fresh, single-branch clone so the dead 2021 branches (`new_related`/`newbranch`/`test`) and the
stale `origin/master` are left behind:

```
git clone --single-branch --branch main <valiant-checkout> <work-dir>/DBIO-Valiant
cd <work-dir>/DBIO-Valiant
git filter-repo \
  --path lib/DBIO/ \
  --path t/dbio/ \
  --path t/lib/ExampleIO/ \
  --path t/lib/SchemaIO/ \
  --path t/lib/TestDBIO.pm
```

Working directory: sibling of the Valiant checkout (e.g. `~/Desktop/DBIO-Valiant`), adjustable.
Result: repo containing only those paths, at their current (dist-correct) locations, with the
history slice that touched them — the DBIO port commits plus the two shared-fix commits
(`delete_omitted`, single-rel `allow_destroy`) rewritten to their DBIO portion.

Path-set closure was verified: the DBIO lane references no `t/lib/locale/en.pl`, no shared
`t/lib` validators, and no DBIC schema. `NO1::Result` is an inline test package, not a file.

### Phase 3 — Scaffold (mirror Valiant)

- **`dist.ini`**: `name = DBIO::Valiant`, `version = 0.001001`, author/license/copyright copied
  from Valiant; `[@Basic]`, `[MetaJSON]`, `[MetaResources]` pointing at the new repo,
  `[Prereqs::FromCPANfile]`. Omit `[MetaNoIndex]` (no `example/` or Catalyst namespace here).
  `[PruneFiles]` for any carried dev docs (see below).
- **`cpanfile`** (Valiant's flat style — explicit enumeration, plus an `on test` block):
  - Runtime `requires`: `Valiant`, `DBIO`, and DBIO::Valiant's own direct CPAN `use`-deps
    (e.g. Moo, Scalar::Util, Module::Runtime, …).
  - `on test`: `DBIO::SQLite` (the driver — test-only, like Test::DBIx::Class/DBD::SQLite is
    for the DBIC lane), `Test::Most`, `Test::Lib`, `Test::Needs`, `DateTime`,
    `DateTime::Format::Strptime`, `MooseX::NonMoose`, `MooseX::MarkAsMethods`.
  - The **exact** runtime dep list (and version pins) is derived during implementation by
    scanning the modules' `use` statements and confirmed by the clean install in Phase 4 — not
    guessed here.
- **`Changes`**: fresh file opening at `0.001001` ("Initial release — extracted from Valiant;
  DBIO integration mirroring DBIx::Class::Valiant"), carrying the DBIO-relevant prose from the
  monorepo `0.002020` entry.
- **CI/config**: copy `.github/workflows/{linux,macos}.yml`, `.codecov.yml`, `.gitignore` from
  Valiant, adjusting only what the new dep set requires.
- **`README.mkdn`**: generated from `lib/DBIO/Valiant.pm` POD the same way Valiant generates
  its README from `lib/Valiant.pm`.
- **Provenance docs**: carry `dbio-integration-notes.md` and
  `docs/superpowers/plans/2026-07-07-dbio-valiant-port.md` into the new repo's `docs/` (pruned
  from the tarball) so the new repo keeps its design history.

### Phase 4 — Prove it stands alone

Under perlbrew (`perl-5.40.0@default`), inside the extracted repo:

```
cpanm --installdeps .
prove -lr t
```

Must reach the same green as the DBIO lane does in the monorepo, using real in-memory SQLite
via `DBIO::SQLite`. Resolve anything the run surfaces:

- Any missing dependency → add to `cpanfile`.
- The stray `Devel::Dwarn` reference in the DBIO lane → declare it as a test dep or remove the
  debug line, so test output stays pristine.

### Phase 5 — Publish (outward-facing)

Only after Phase 4 is green **and** John has reviewed the built repo:

- `gh repo create jjn1056/DBIO-Valiant --public` (Perl_5), confirm `gh` auth first.
- Push the filtered history + scaffolding to the new remote's `main`.

### Phase 6 — Clean core Valiant

Separate commit on core `main`:

- `git rm -r lib/DBIO t/dbio t/lib/ExampleIO t/lib/SchemaIO t/lib/TestDBIO.pm`.
- Remove **only** the `DBIO` and `DBIO::SQLite` lines from `cpanfile` (the MooseX/DateTime test
  deps predate this branch and other tests use them — they stay).
- Keep the `lib/Valiant.pm` POD cross-link to `DBIO::Valiant` (now a sibling dist); regenerate
  `README.mkdn`.
- `prove -lr t` stays green (fewer tests; DBIx::Class lane untouched).
- Leave the `dbio-integration-notes.md` / `docs/` prune lines in `dist.ini` (those docs remain
  in core as monorepo history unless we decide to move them).

## Verification strategy

- Real backends only, no mocks (per project rule): in-memory SQLite via `DBIO::SQLite`.
- Green gate at each phase: after FF (`main` green), after extraction (new repo green in
  isolation), after core cleanup (core green).
- Pristine test output — any expected error/warning is captured and asserted, not left loose.

## Checkpoints for John's review

1. After FF + push `main`.
2. After the extracted repo is green in isolation (before any GitHub action).
3. Before creating/pushing the `jjn1056/DBIO-Valiant` GitHub repo.
4. After core cleanup is green.

## Risks & mitigations

- **Missing a needed file in the filter path set** → repo fails in isolation. Mitigated by the
  verified closure (Phase 2) and the clean-install run (Phase 4) as the real proof.
- **Pushing rewritten history to Valiant by accident** → filter-repo drops `origin`; new repo
  gets a new remote only.
- **cpanfile dep drift** (transitive deps that were satisfied by the monorepo but not declared)
  → caught by `cpanm --installdeps .` on a clean perl in Phase 4.
- **Outward-facing steps** (push `main`, create GitHub repo) gated behind explicit checkpoints.

## Follow-on (out of scope here)

- **DBIx::Class::Valiant extraction** — same recipe, from `main`, keeping
  `lib/DBIx/Class/Valiant.pm` + `lib/DBIx/Class/Valiant/**`, `t/dbic/**`,
  `t/lib/{Example,Schema}/**`, `t/lib/locale/en.pl`; then remove `DBIx::Class`,
  `DBIx::Class::Candy`, `Test::DBIx::Class` from core.
- Deferred `insert_async` validation override (blocked on unreleased DBIO async subsystem).
- Cosmetic cleanup carried from the port: copy-paste `=head1 NAME` in the three
  `Util/Exception` subclasses; stray `.DS_Store` files.
