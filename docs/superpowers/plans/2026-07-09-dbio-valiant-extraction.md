# DBIO::Valiant Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the DBIO integration out of the Valiant monorepo into a standalone, history-preserving `DBIO::Valiant` distribution published on GitHub, then remove the now-unused DBIO code and dependencies from core Valiant.

**Architecture:** Fast-forward `main` to the finished `dbio-integration` branch, then `git-filter-repo` a fresh clone down to the DBIO paths (preserving their commit history), scaffold a Dist::Zilla dist mirroring Valiant's setup, prove it green in isolation against real in-memory SQLite, publish to GitHub, and finally strip DBIO from core in a reviewable PR. DBIx::Class::Valiant is left in core untouched — its identical extraction is a later cycle.

**Tech Stack:** Perl (perlbrew `perl-5.40.0@default`), Dist::Zilla (`[@Basic]` + cpanfile via `[Prereqs::FromCPANfile]`), `git-filter-repo`, DBIO + DBIO::SQLite, Test::Most/Test::Lib/Test::Needs, `gh` CLI, GitHub Actions CI.

## Global Constraints

- Perl commands MUST run under perlbrew: prefix with `source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default`.
- Perl **5.20** compatibility floor (Valiant); DBIO's own floor is 5.008001 — no conflict. Keep the CI perl matrix as Valiant's.
- **No mocks in end-to-end tests** — real in-memory SQLite via `DBIO::SQLite`, exactly as the monorepo DBIO lane does today.
- **Test output must be pristine** — resolve any stray debugging output (e.g. `Devel::Dwarn`).
- **No behavior changes** to the DBIO integration during extraction — only moves, scaffolding, and dependency wiring.
- **Preserve git history** — use `git-filter-repo`; never squash.
- **Mirror Valiant's Dist::Zilla + dependency management** for the new dist.
- **Never `git add -A`; never add the untracked root `CLAUDE.md`.** Add only explicitly named paths.
- End commit messages with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Outward-facing steps are gated** behind John's review: push `main` (Checkpoint 1), extracted repo green (Checkpoint 2), create/push GitHub repo (Checkpoint 3), core-cleanup PR (Checkpoint 4).
- Paths: Valiant checkout = `/Users/jnapiorkowski/Desktop/Valiant`; new repo working dir = `/Users/jnapiorkowski/Desktop/DBIO-Valiant`.
- Verified DBIO path set: `lib/DBIO/` · `t/dbio/` · `t/lib/ExampleIO/` · `t/lib/SchemaIO/` · `t/lib/TestDBIO.pm`.

---

### Task 1: Fast-forward `main` and push

**Files:** none (git ref move only).

**Interfaces:**
- Consumes: the `dbio-integration` branch at HEAD (contains the 38 port commits + the spec + this plan).
- Produces: `origin/main` == the DBIO work; PR #13 auto-closed; the extraction source of truth.

- [ ] **Step 1: Confirm this plan + spec are committed on `dbio-integration`**

Run: `git -C /Users/jnapiorkowski/Desktop/Valiant status --short`
Expected: only `?? CLAUDE.md` (spec and plan already committed; nothing else staged/modified).

- [ ] **Step 2: Confirm the fast-forward is legal (main fully contained)**

Run: `git -C /Users/jnapiorkowski/Desktop/Valiant rev-list --count dbio-integration..main`
Expected: `0` (nothing on main that isn't on the branch → FF is safe).

- [ ] **Step 3: Fast-forward main**

```bash
git -C /Users/jnapiorkowski/Desktop/Valiant checkout main
git -C /Users/jnapiorkowski/Desktop/Valiant merge --ff-only dbio-integration
```
Expected: `Fast-forward` in the output; `main` now points at the branch HEAD.

- [ ] **Step 4: Push main**

Run: `git -C /Users/jnapiorkowski/Desktop/Valiant push origin main`
Expected: `origin/main` updated; remote accepts the fast-forward.

- [ ] **Step 5: Verify PR #13 auto-closed and suite still green**

```bash
gh pr view 13 --repo jjn1056/Valiant --json state --jq '.state'
bash -c 'cd /Users/jnapiorkowski/Desktop/Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && prove -lr t 2>&1 | tail -3'
```
Expected: PR state `MERGED`; test summary ends `Result: PASS` (≈102 files / 2411 tests).

- [ ] **Step 6: CHECKPOINT 1 — report to John** (main is now the source of truth) before proceeding.

---

### Task 2: Extract DBIO history with `git-filter-repo`

**Files:** creates the new repo at `/Users/jnapiorkowski/Desktop/DBIO-Valiant` (filtered history; no scaffolding yet).

**Interfaces:**
- Consumes: `/Users/jnapiorkowski/Desktop/Valiant` `main`.
- Produces: a git repo containing ONLY the DBIO path set, with preserved per-file history and no `origin` remote.

- [ ] **Step 1: Fresh single-branch clone** (leaves the dead 2021 branches and stale `origin/master` behind)

Run: `git clone --single-branch --branch main /Users/jnapiorkowski/Desktop/Valiant /Users/jnapiorkowski/Desktop/DBIO-Valiant`
Expected: `Cloning into '.../DBIO-Valiant'... done.`

- [ ] **Step 2: Filter to the DBIO path set**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant filter-repo \
  --path lib/DBIO/ \
  --path t/dbio/ \
  --path t/lib/ExampleIO/ \
  --path t/lib/SchemaIO/ \
  --path t/lib/TestDBIO.pm
```
Expected: filter-repo runs (fresh clone, no `--force` needed) and ends `... completely finished.`

- [ ] **Step 3: Verify ONLY the DBIO paths survived**

Run: `git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant ls-files | grep -vE '^(lib/DBIO/|t/dbio/|t/lib/ExampleIO/|t/lib/SchemaIO/|t/lib/TestDBIO\.pm)'`
Expected: **no output** (every tracked file is in the DBIO path set). Also spot-check counts: `git -C ... ls-files | wc -l` ≈ 84 files.

- [ ] **Step 4: Verify history was preserved, not squashed**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant log --oneline | wc -l
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant log --oneline -- lib/DBIO/Valiant/Result.pm | wc -l
```
Expected: first count > 20 (the DBIO-touching commit subset); second count > 1 (Result.pm carries multiple commits — real history, not one squashed commit).

- [ ] **Step 5: Verify `origin` was dropped by filter-repo**

Run: `git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant remote -v`
Expected: **no output** (no remote — protects against pushing rewritten history back to Valiant).

No commit — the filtered history IS the deliverable.

---

### Task 3: Scaffold dist metadata (mirror Valiant)

**Files:**
- Create: `/Users/jnapiorkowski/Desktop/DBIO-Valiant/dist.ini`
- Create: `/Users/jnapiorkowski/Desktop/DBIO-Valiant/Changes`
- Create: `/Users/jnapiorkowski/Desktop/DBIO-Valiant/.gitignore`
- Create: `/Users/jnapiorkowski/Desktop/DBIO-Valiant/.codecov.yml`
- Create: `/Users/jnapiorkowski/Desktop/DBIO-Valiant/.github/workflows/linux.yml`, `.../macos.yml`
- Create: `/Users/jnapiorkowski/Desktop/DBIO-Valiant/docs/*` (provenance copies)

**Interfaces:**
- Consumes: the filtered repo from Task 2.
- Produces: a buildable Dist::Zilla layout (deps land in Task 4).

- [ ] **Step 1: Write `dist.ini`**

```ini
name    = DBIO-Valiant
author  = John Napiorkowski <jjnapiork@cpan.org>
license = Perl_5
copyright_holder = John Napiorkowski
copyright_year   = 2026
abstract = Glue Valiant validations into DBIO
version = 0.001001

[@Basic]
[MetaJSON]

[MetaResources]
homepage = https://github.com/jjn1056/DBIO-Valiant
bugtracker.web  = https://github.com/jjn1056/DBIO-Valiant/issues
repository.web  = https://github.com/jjn1056/DBIO-Valiant
repository.url  = https://github.com/jjn1056/DBIO-Valiant
repository.type = git

[PruneFiles]
match = ^docs/

[Prereqs::FromCPANfile]
```

- [ ] **Step 2: Write `Changes`** (hand-maintained, Valiant style)

```
Revision history for Perl distribution DBIO-Valiant

0.001001  {{TBD}}
        - Initial release.  DBIO::Valiant provides Ruby-on-Rails-inspired,
          Valiant-powered domain validations for DBIO (the asynchronous fork
          of DBIx::Class), mirroring the DBIx::Class::Valiant integration:
          filter-on-new, validate-on-insert/update, nested creates/updates
          across relationships (accept_nested_for), and FormBuilder glue.
        - Extracted from the Valiant distribution with development history
          preserved.
```

- [ ] **Step 3: Copy CI + coverage config verbatim** (they are dist-name-agnostic: `cpanm --installdeps .` + `prove -lr t`)

```bash
mkdir -p /Users/jnapiorkowski/Desktop/DBIO-Valiant/.github/workflows
cp /Users/jnapiorkowski/Desktop/Valiant/.github/workflows/linux.yml /Users/jnapiorkowski/Desktop/DBIO-Valiant/.github/workflows/linux.yml
cp /Users/jnapiorkowski/Desktop/Valiant/.github/workflows/macos.yml /Users/jnapiorkowski/Desktop/DBIO-Valiant/.github/workflows/macos.yml
cp /Users/jnapiorkowski/Desktop/Valiant/.codecov.yml /Users/jnapiorkowski/Desktop/DBIO-Valiant/.codecov.yml
```

- [ ] **Step 4: Write `.gitignore`** (Valiant's, minus the Valiant-only `example` line, plus `.DS_Store` hygiene)

```
.vscode/
.vscode/**/*
.DS_Store
```

- [ ] **Step 5: Carry provenance docs** (kept in-repo, pruned from the tarball by `[PruneFiles]`)

```bash
mkdir -p /Users/jnapiorkowski/Desktop/DBIO-Valiant/docs
cp /Users/jnapiorkowski/Desktop/Valiant/dbio-integration-notes.md /Users/jnapiorkowski/Desktop/DBIO-Valiant/docs/dbio-integration-notes.md
cp /Users/jnapiorkowski/Desktop/Valiant/docs/superpowers/plans/2026-07-07-dbio-valiant-port.md /Users/jnapiorkowski/Desktop/DBIO-Valiant/docs/2026-07-07-dbio-valiant-port.md
cp /Users/jnapiorkowski/Desktop/Valiant/docs/superpowers/specs/2026-07-09-dbio-valiant-extraction-design.md /Users/jnapiorkowski/Desktop/DBIO-Valiant/docs/2026-07-09-dbio-valiant-extraction-design.md
```

- [ ] **Step 6: Verify files present**

Run: `git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant status --short`
Expected: the new `dist.ini`, `Changes`, `.gitignore`, `.codecov.yml`, `.github/`, `docs/` shown as untracked (`??`).

- [ ] **Step 7: Commit**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant add dist.ini Changes .gitignore .codecov.yml .github docs
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant commit -m "$(printf 'Scaffold DBIO-Valiant dist (Dist::Zilla, CI, provenance docs)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```
Expected: one commit created.

---

### Task 4: `cpanfile` + prove green in isolation

**Files:**
- Create: `/Users/jnapiorkowski/Desktop/DBIO-Valiant/cpanfile`
- Possibly modify: a `t/dbio/*.t` file if it carries a stray `use Devel::Dwarn;`

**Interfaces:**
- Consumes: the scaffolded repo (Task 3) + the extracted code/tests (Task 2).
- Produces: a self-contained dist that installs its deps and passes its suite standalone.

- [ ] **Step 1: Write `cpanfile`** (runtime deps = DBIO::Valiant's direct `use`-deps, pinned to Valiant's versions; test deps mirror the monorepo DBIO lane)

```perl
requires 'Valiant', '0.002019';
requires 'DBIO', '0.900000';
requires 'Carp', '1.50';
requires 'DateTime', '1.65';
requires 'DateTime::Format::Strptime', '1.79';
requires 'Moo', '2.005005';
requires 'namespace::autoclean', '0.29';
requires 'Role::Tiny::With', '2.002004';
requires 'Scalar::Util', '1.63';

on test => sub {
  requires 'DBIO::SQLite', '0.900000';
  requires 'Test::Most', '0.38';
  requires 'Test::Lib', '0.003';
  requires 'Test::Needs', '0.002010';
  requires 'MooseX::NonMoose';
  requires 'MooseX::MarkAsMethods';
};
```

- [ ] **Step 2: Locate and resolve any stray `Devel::Dwarn`** (keeps output pristine + deps minimal)

Run: `grep -rn 'Dwarn' /Users/jnapiorkowski/Desktop/DBIO-Valiant/t`
Then: if a committed test has a leftover `use Devel::Dwarn;` (a debugging line, not asserted output), remove that line with Edit. If the grep returns nothing, skip. Do NOT add `Devel::Dwarn` to `cpanfile` unless a test genuinely depends on its output.

- [ ] **Step 3: Install deps in isolation** (core Valiant satisfied from the local checkout so we don't depend on CPAN release timing; everything else from CPAN/local perlbrew)

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/DBIO-Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && PERL5LIB=/Users/jnapiorkowski/Desktop/Valiant/lib cpanm --installdeps --skip-satisfied .'
```
Expected: `<== OK` / "installed" for any missing deps; no unresolved-dependency error. If a dependency is reported missing that the runtime genuinely needs, add it to `cpanfile` and re-run.

- [ ] **Step 4: Run the suite in isolation** (`-l` adds `lib/`; `PERL5LIB` supplies core Valiant)

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/DBIO-Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && PERL5LIB=/Users/jnapiorkowski/Desktop/Valiant/lib prove -lr t 2>&1 | tail -8'
```
Expected: `Result: PASS`, with the same DBIO lane counts as the monorepo (28 `t/dbio/` files). Any failure here is a real gap — fix (missing dep or file) before continuing; do not paper over.

- [ ] **Step 5: Commit**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant add cpanfile
# include the test file too if Step 2 edited one, e.g.:
# git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant add t/dbio/<file>.t
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant commit -m "$(printf 'Add cpanfile; DBIO-Valiant suite green in isolation\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```
Expected: one commit created.

- [ ] **Step 6: CHECKPOINT 2 — report green + counts to John.**

---

### Task 5: Generate `README.mkdn`

**Files:**
- Create: `/Users/jnapiorkowski/Desktop/DBIO-Valiant/README.mkdn`

**Interfaces:**
- Consumes: `lib/DBIO/Valiant.pm` POD.
- Produces: the rendered README (Valiant renders its README from its main module's POD the same way).

- [ ] **Step 1: Ensure `pod2markdown` is available**

Run: `bash -c 'source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && which pod2markdown || cpanm --notest Pod::Markdown'`
Expected: a path to `pod2markdown` (installs `Pod::Markdown` if absent).

- [ ] **Step 2: Generate the README from POD**

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/DBIO-Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && pod2markdown lib/DBIO/Valiant.pm > README.mkdn'
```
Expected: `README.mkdn` created.

- [ ] **Step 3: Verify content**

Run: `head -5 /Users/jnapiorkowski/Desktop/DBIO-Valiant/README.mkdn`
Expected: the DBIO::Valiant NAME/abstract heading. (Confirm with John this matches how he generates Valiant's README; adjust the tool if his workflow differs.)

- [ ] **Step 4: Commit**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant add README.mkdn
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant commit -m "$(printf 'Generate README.mkdn from DBIO::Valiant POD\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 6: Create GitHub repo and push (outward-facing)

**Files:** none (remote creation + push).

**Interfaces:**
- Consumes: the local `DBIO-Valiant` repo (Tasks 2–5).
- Produces: `https://github.com/jjn1056/DBIO-Valiant` with full history.

- [ ] **Step 1: (Gate) Do not run this task until Checkpoint 3 — John has reviewed the built repo.**

- [ ] **Step 2: Confirm `gh` is authenticated**

Run: `gh auth status`
Expected: logged in to github.com as the account owning `jjn1056`. If not, stop and ask John to run `! gh auth login`.

- [ ] **Step 3: Create the repo and push**

```bash
gh repo create jjn1056/DBIO-Valiant --public \
  --description "Glue Valiant validations into DBIO (the asynchronous fork of DBIx::Class)" \
  --source /Users/jnapiorkowski/Desktop/DBIO-Valiant --remote origin --push
```
Expected: repo created; `origin` added; local `main` pushed.

- [ ] **Step 4: Verify**

```bash
gh repo view jjn1056/DBIO-Valiant --json url,visibility,defaultBranchRef --jq '{url,visibility,default:.defaultBranchRef.name}'
git -C /Users/jnapiorkowski/Desktop/DBIO-Valiant log --oneline origin/main | wc -l
```
Expected: public repo, default branch `main`, and the pushed commit count matches local history.

---

### Task 7: Clean DBIO out of core Valiant (reviewable PR)

**Files:**
- Delete (in `/Users/jnapiorkowski/Desktop/Valiant`): `lib/DBIO/`, `t/dbio/`, `t/lib/ExampleIO/`, `t/lib/SchemaIO/`, `t/lib/TestDBIO.pm`
- Modify: `cpanfile` (remove the two DBIO lines)
- Modify: `README.mkdn` (regenerate; keeps the DBIO::Valiant POD cross-link)

**Interfaces:**
- Consumes: core Valiant `main` (post-Task-1).
- Produces: a PR removing DBIO from core; core stays green; DBIx::Class lane untouched.

- [ ] **Step 1: Branch off up-to-date main**

```bash
git -C /Users/jnapiorkowski/Desktop/Valiant checkout main
git -C /Users/jnapiorkowski/Desktop/Valiant pull --ff-only
git -C /Users/jnapiorkowski/Desktop/Valiant checkout -b remove-dbio-integration
```
Expected: on new branch `remove-dbio-integration`.

- [ ] **Step 2: Remove the DBIO code + tests + test-support**

```bash
git -C /Users/jnapiorkowski/Desktop/Valiant rm -r lib/DBIO t/dbio t/lib/ExampleIO t/lib/SchemaIO t/lib/TestDBIO.pm
```
Expected: git reports the removed files staged for deletion.

- [ ] **Step 3: Remove ONLY the two DBIO lines from `cpanfile`**

Edit `/Users/jnapiorkowski/Desktop/Valiant/cpanfile`, deleting exactly:
```perl
  requires 'DBIO' => '0.900000';
  requires 'DBIO::SQLite' => '0.900000';
```
Leave `MooseX::NonMoose`, `MooseX::MarkAsMethods`, `DateTime*`, and the DBIx::Class deps in place (other tests use them).

- [ ] **Step 4: Regenerate the core README** (POD still links DBIO::Valiant as a sibling dist — kept)

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && pod2markdown lib/Valiant.pm > README.mkdn'
```
Expected: `README.mkdn` updated (now includes the DBIO::Valiant cross-references added on the branch).

- [ ] **Step 5: Verify core is still green (DBIO lane gone, DBIC lane intact)**

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && prove -lr t 2>&1 | tail -4'
```
Expected: `Result: PASS`; file count dropped by 28 (the `t/dbio/` files) to ≈74; `t/dbic/` still runs.

- [ ] **Step 6: Commit and push the branch**

```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add cpanfile README.mkdn
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Remove DBIO integration (extracted to DBIO-Valiant dist)\n\nDBIO::Valiant now lives at https://github.com/jjn1056/DBIO-Valiant.\nDrops lib/DBIO, t/dbio, the ExampleIO/SchemaIO test schemas, and the\nDBIO/DBIO::SQLite test deps. DBIx::Class::Valiant is unaffected.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
git -C /Users/jnapiorkowski/Desktop/Valiant push -u origin remove-dbio-integration
```

- [ ] **Step 7: Open the PR**

```bash
gh pr create --repo jjn1056/Valiant --base main --head remove-dbio-integration \
  --title "Remove DBIO integration (extracted to DBIO-Valiant dist)" \
  --body "DBIO::Valiant is now its own distribution: https://github.com/jjn1056/DBIO-Valiant. This removes lib/DBIO, t/dbio, the ExampleIO/SchemaIO test schemas + TestDBIO.pm, and the DBIO/DBIO::SQLite test deps from core. DBIx::Class::Valiant is untouched (its extraction is a later cycle). Suite stays green.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 8: CHECKPOINT 4 — John reviews the PR before merge.**

---

## Checkpoints (outward-facing gates)

1. After Task 1 — `main` fast-forwarded and pushed.
2. After Task 4 — extracted repo green in isolation (before any GitHub action).
3. Before Task 6 — creating/pushing the `jjn1056/DBIO-Valiant` GitHub repo.
4. After Task 7 — core-cleanup PR up for review before merge.

## Out of scope (later cycle)

- DBIx::Class::Valiant extraction (same recipe; keeps `lib/DBIx/Class/Valiant.pm` + `lib/DBIx/Class/Valiant/**`, `t/dbic/**`, `t/lib/{Example,Schema}/**`, `t/lib/locale/en.pl`; then removes `DBIx::Class`, `DBIx::Class::Candy`, `Test::DBIx::Class` from core).
- Deferred `insert_async` validation override (blocked on unreleased DBIO async subsystem).
- Cosmetic cleanup: copy-paste `=head1 NAME` in the three `Util/Exception` subclasses; stray `.DS_Store` files.
- CPAN upload of DBIO::Valiant.
