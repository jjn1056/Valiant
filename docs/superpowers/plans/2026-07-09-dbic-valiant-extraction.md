# DBIx::Class::Valiant Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the DBIx::Class integration out of the Valiant monorepo into a standalone, history-preserving `DBIx::Class::Valiant` distribution published on GitHub, then remove the now-extracted code and dependencies from core Valiant.

**Architecture:** Same recipe as the completed DBIO extraction. `main` is already current (the DBIO removal is merged), so no fast-forward is needed. `git-filter-repo` a fresh clone down to the verified DBIC path set (preserving 134/78 commits of history), strip stray `.DS_Store` from the new repo's history, scaffold a Dist::Zilla dist mirroring Valiant, prove it green in isolation against real SQLite, publish, then strip DBIC from core in a reviewable PR.

**Tech Stack:** Perl (perlbrew `perl-5.40.0@default`), Dist::Zilla (`[@Basic]` + cpanfile via `[Prereqs::FromCPANfile]`), `git-filter-repo`, DBIx::Class + DBIx::Class::Candy + Test::DBIx::Class, `gh` CLI, GitHub Actions CI.

## Global Constraints

- Perl commands MUST run under perlbrew: prefix with `source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default`.
- When running the new repo's suite, core Valiant is supplied from the local checkout by **prepending** to PERL5LIB (never replacing it — perlbrew's local::lib lives there): `PERL5LIB=/Users/jnapiorkowski/Desktop/Valiant/lib:$PERL5LIB`.
- `git-filter-repo` on a **local** clone requires `git clone --no-local` or it refuses to run.
- Perl **5.20** compatibility floor; keep the CI perl matrix as Valiant's.
- **No mocks in end-to-end tests** — real SQLite via Test::DBIx::Class (in-memory), as the tests already do.
- **Test output must be pristine.**
- **No behavior changes** to the DBIC integration during extraction — only moves, scaffolding, dependency wiring, and the two explicitly-listed fixes (`.DS_Store` strip, `delete-omitted.t` stale comment).
- **Preserve git history** — use `git-filter-repo`; never squash.
- **Mirror Valiant's Dist::Zilla + dependency management** for the new dist.
- **Never `git add -A`; never add the untracked root `CLAUDE.md`.** Add only explicitly named paths.
- End commit messages with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Outward-facing steps are gated** behind John's review: create/push the GitHub repo (Checkpoint B), the core-cleanup PR (Checkpoint C).
- Paths: Valiant checkout = `/Users/jnapiorkowski/Desktop/Valiant`; new repo working dir = `/Users/jnapiorkowski/Desktop/DBIx-Class-Valiant`.
- **Verified DBIC keep/path set** (filter-repo `--path`): `lib/DBIx/Class/Valiant.pm` · `lib/DBIx/Class/Valiant/` · `t/dbic/` · `t/lib/Example/Schema.pm` · `t/lib/Example/Schema/` · `t/lib/Schema/`.
- **Do NOT move** `t/lib/locale/en.pl` (core-shared, used by `t/ancestors.t`) or `t/lib/Example/HTML*` (unrelated core dead code).

---

### Task 1: Extract DBIC history with `git-filter-repo`

**Files:** creates the new repo at `/Users/jnapiorkowski/Desktop/DBIx-Class-Valiant` (filtered history; no scaffolding yet).

**Interfaces:**
- Consumes: `/Users/jnapiorkowski/Desktop/Valiant` `main` (post-DBIO-removal).
- Produces: a git repo containing ONLY the DBIC path set, `.DS_Store`-free, with preserved history and no `origin` remote.

- [ ] **Step 1: Fresh single-branch clone** (`--no-local` is REQUIRED for local-path clones or filter-repo refuses)

Run: `git clone --no-local --single-branch --branch main /Users/jnapiorkowski/Desktop/Valiant /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant`
Expected: `Cloning into '.../DBIx-Class-Valiant'... done.`

- [ ] **Step 2: Filter to the DBIC path set**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant filter-repo \
  --path lib/DBIx/Class/Valiant.pm \
  --path lib/DBIx/Class/Valiant/ \
  --path t/dbic/ \
  --path t/lib/Example/Schema.pm \
  --path t/lib/Example/Schema/ \
  --path t/lib/Schema/
```
Expected: filter-repo runs and ends `... completely finished.`

- [ ] **Step 3: Strip stray `.DS_Store` from all history** (second pass needs `--force` since it's no longer a pristine clone)

Run: `git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant filter-repo --invert-paths --path-glob '*.DS_Store' --force`
Expected: finishes; `.DS_Store` gone from the tree and history.

- [ ] **Step 4: Verify ONLY the DBIC paths survived, no `.DS_Store`, no `locale`/`HTML`**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant ls-files | grep -vE '^(lib/DBIx/Class/Valiant|t/dbic/|t/lib/Example/Schema|t/lib/Schema/)'
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant ls-files | grep -E 'DS_Store|locale/en\.pl|Example/HTML'
```
Expected: **both greps produce NO output** (first: everything is in the keep set; second: no junk/mis-included files). Spot-check total: `git -C ... ls-files | wc -l` ≈ 75.

- [ ] **Step 5: Verify history preserved and `origin` dropped**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant log --oneline -- lib/DBIx/Class/Valiant/Result.pm | wc -l
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant remote -v
```
Expected: Result.pm commit count > 1 (deep history, not squashed); no remote listed.

No commit — the filtered history is the deliverable.

---

### Task 2: Scaffold dist metadata (mirror Valiant)

**Files:**
- Create in `/Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/`: `dist.ini`, `Changes`, `.gitignore`, `.codecov.yml`, `.github/workflows/{linux,macos}.yml`, `docs/*` (provenance).

**Interfaces:**
- Consumes: the filtered repo from Task 1.
- Produces: a buildable Dist::Zilla layout (deps land in Task 3).

- [ ] **Step 1: Write `dist.ini`**

```ini
name    = DBIx-Class-Valiant
author  = John Napiorkowski <jjnapiork@cpan.org>
license = Perl_5
copyright_holder = John Napiorkowski
copyright_year   = 2026
abstract = Glue Valiant validations into DBIx::Class
version = 0.001001

[@Basic]
[MetaJSON]

[MetaResources]
homepage = https://github.com/jjn1056/DBIx-Class-Valiant
bugtracker.web  = https://github.com/jjn1056/DBIx-Class-Valiant/issues
repository.web  = https://github.com/jjn1056/DBIx-Class-Valiant
repository.url  = https://github.com/jjn1056/DBIx-Class-Valiant
repository.type = git

[PruneFiles]
match = ^docs/

[Prereqs::FromCPANfile]
```

- [ ] **Step 2: Write `Changes`** (hand-maintained, Valiant's header style)

```
The following logs changes for the CPAN distribution DBIx-Class-Valiant

0.001001  {{TBD}}
        - Initial standalone release.  DBIx::Class::Valiant provides
          Ruby-on-Rails-inspired, Valiant-powered domain validations for
          DBIx::Class: filter-on-new, validate-on-insert/update, nested
          creates/updates across relationships (accept_nested_for), and
          FormBuilder glue.
        - Extracted from the Valiant distribution with development history
          preserved.
```

- [ ] **Step 3: Copy CI + coverage config verbatim** (dist-name-agnostic)

```bash
mkdir -p /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/.github/workflows
cp /Users/jnapiorkowski/Desktop/Valiant/.github/workflows/linux.yml /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/.github/workflows/linux.yml
cp /Users/jnapiorkowski/Desktop/Valiant/.github/workflows/macos.yml /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/.github/workflows/macos.yml
cp /Users/jnapiorkowski/Desktop/Valiant/.codecov.yml /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/.codecov.yml
```

- [ ] **Step 4: Write `.gitignore`** (includes `.DS_Store` so the junk never comes back)

```
.vscode/
.vscode/**/*
.DS_Store
```

- [ ] **Step 5: Carry provenance docs** (pruned from the tarball by `[PruneFiles]`)

```bash
mkdir -p /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/docs
cp /Users/jnapiorkowski/Desktop/Valiant/dbio-integration-notes.md /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/docs/dbio-integration-notes.md
cp /Users/jnapiorkowski/Desktop/Valiant/docs/superpowers/specs/2026-07-09-dbio-valiant-extraction-design.md /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/docs/2026-07-09-extraction-design.md
cp /Users/jnapiorkowski/Desktop/Valiant/docs/superpowers/plans/2026-07-09-dbic-valiant-extraction.md /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/docs/2026-07-09-dbic-valiant-extraction.md
```

- [ ] **Step 6: Verify + commit**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant status --short
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant add dist.ini Changes .gitignore .codecov.yml .github docs
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant commit -m "$(printf 'Scaffold DBIx-Class-Valiant dist (Dist::Zilla, CI, provenance docs)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```
Expected: one commit; `dist.ini`/`Changes`/`.gitignore`/`.codecov.yml`/`.github`/`docs` added, nothing else.

---

### Task 3: cpanfile + fix stale comment + prove green in isolation

**Files:**
- Create: `/Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/cpanfile`
- Modify: `/Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/t/dbic/delete-omitted.t` (stale `t/dbio/` comment)

**Interfaces:**
- Consumes: scaffolded repo (Task 2) + extracted code/tests (Task 1).
- Produces: a self-contained dist that installs its deps and passes its suite standalone.

- [ ] **Step 1: Write `cpanfile`** (runtime = DBIC's direct `use`-deps at Valiant's pins; test = the DBIC harness)

```perl
requires 'Valiant', '0.002019';
requires 'DBIx::Class', '0.082843';
requires 'DBIx::Class::Candy', '0.005003';
requires 'Carp', '1.50';
requires 'DateTime', '1.65';
requires 'DateTime::Format::Strptime', '1.79';
requires 'Moo', '2.005005';
requires 'namespace::autoclean', '0.29';
requires 'Role::Tiny::With', '2.002004';
requires 'Scalar::Util', '1.63';

on test => sub {
  requires 'Test::DBIx::Class', '0.52';
  requires 'Test::Most', '0.38';
  requires 'Test::Lib', '0.003';
  requires 'Test::Needs', '0.002010';
  requires 'MooseX::NonMoose';
  requires 'MooseX::MarkAsMethods';
};
```

- [ ] **Step 2: Fix the stale cross-reference in `t/dbic/delete-omitted.t`**

The header comment references `t/dbio/nested-options.t`, which no longer exists here (DBIO was extracted). Open the file, find the comment mentioning `t/dbio/`, and reword it to drop the dead path (e.g. point at "the DBIO::Valiant distribution" or remove the parenthetical). Do not change any test logic.

- [ ] **Step 3: Install deps in isolation** (core Valiant satisfied from the local checkout via PREPENDED PERL5LIB)

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && PERL5LIB=/Users/jnapiorkowski/Desktop/Valiant/lib:$PERL5LIB cpanm --installdeps --skip-satisfied .'
```
Expected: everything satisfied (these deps are already installed in the perlbrew env from the monorepo). If a genuinely-needed dep is missing, add ONLY that to `cpanfile` and re-run.

- [ ] **Step 4: Run the suite in isolation**

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && PERL5LIB=/Users/jnapiorkowski/Desktop/Valiant/lib:$PERL5LIB prove -lr t 2>&1 | tail -8'
```
Expected: `Result: PASS`, 12 `t/dbic/` files, matching the monorepo DBIC lane counts. Fix any real failure at the root; never weaken/skip a test.

- [ ] **Step 5: Commit**

```bash
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant add cpanfile t/dbic/delete-omitted.t
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant commit -m "$(printf 'Add cpanfile; fix stale t/dbio cross-ref; suite green in isolation\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

- [ ] **Step 6: CHECKPOINT A — report green + counts to John.**

---

### Task 4: Generate `README.mkdn`

**Files:** Create `/Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/README.mkdn`

**Interfaces:** Consumes `lib/DBIx/Class/Valiant.pm` POD → produces the rendered README (Valiant's method).

- [ ] **Step 1: Generate from POD**

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && pod2markdown lib/DBIx/Class/Valiant.pm > README.mkdn'
```
Expected: `README.mkdn` created.

- [ ] **Step 2: Verify + commit**

```bash
head -5 /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant/README.mkdn
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant add README.mkdn
git -C /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant commit -m "$(printf 'Generate README.mkdn from DBIx::Class::Valiant POD\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```
Expected: header shows `DBIx::Class::Valiant - Glue Valiant validations into DBIx::Class`.

- [ ] **Step 3: Sanity-build** (proves releasable + docs pruned) then clean

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && dzil build 2>&1 | tail -4 && dzil clean 2>&1 | tail -2'
```
Expected: `built in DBIx-Class-Valiant-0.001001`; the MANIFEST would exclude `docs/`. `dzil clean` leaves the tree clean.

---

### Task 5: Create GitHub repo and push (outward-facing)

**Files:** none (remote creation + push).

- [ ] **Step 1: Gate — do not run until Checkpoint B (John reviewed the built repo).**

- [ ] **Step 2: Confirm `gh` auth**

Run: `gh auth status`
Expected: logged in as `jjn1056`.

- [ ] **Step 3: Create + push**

```bash
gh repo create jjn1056/DBIx-Class-Valiant --public \
  --description "Glue Valiant validations into DBIx::Class" \
  --source /Users/jnapiorkowski/Desktop/DBIx-Class-Valiant --remote origin --push
```
Expected: repo created; `origin` added; `main` pushed.

- [ ] **Step 4: Verify**

```bash
gh repo view jjn1056/DBIx-Class-Valiant --json url,visibility,defaultBranchRef --jq '{url,visibility,default:.defaultBranchRef.name}'
```
Expected: public, default `main`.

---

### Task 6: Clean DBIC out of core Valiant (reviewable PR)

**Files:**
- Delete (in `/Users/jnapiorkowski/Desktop/Valiant`): `lib/DBIx/Class/Valiant.pm`, `lib/DBIx/Class/Valiant/`, `t/dbic/`, `t/lib/Example/Schema.pm`, `t/lib/Example/Schema/`, `t/lib/Schema/`
- Modify: `cpanfile` (remove the 3 DBIC deps — both occurrences each), `README.mkdn` (regenerate)
- Do NOT touch: `t/lib/locale/en.pl`, `t/lib/Example/HTML*`

**Interfaces:** Consumes core `main`; produces a PR removing DBIC from core; core stays green.

- [ ] **Step 1: Branch off up-to-date main**

```bash
git -C /Users/jnapiorkowski/Desktop/Valiant checkout main
git -C /Users/jnapiorkowski/Desktop/Valiant pull --ff-only
git -C /Users/jnapiorkowski/Desktop/Valiant checkout -b remove-dbic-integration
```

- [ ] **Step 2: Remove the DBIC code + tests + DBIC-only test-support**

```bash
git -C /Users/jnapiorkowski/Desktop/Valiant rm -r -q \
  lib/DBIx/Class/Valiant.pm lib/DBIx/Class/Valiant \
  t/dbic \
  t/lib/Example/Schema.pm t/lib/Example/Schema \
  t/lib/Schema
```
Then confirm the shared files survive:
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant ls-files | grep -E 't/lib/locale/en\.pl|t/lib/Example/HTML'
```
Expected: BOTH still listed (they must remain in core).

- [ ] **Step 3: Remove the 3 DBIC deps from `cpanfile`** (each appears twice — the unconditional block and the `on test` block; 6 lines total)

Edit `/Users/jnapiorkowski/Desktop/Valiant/cpanfile`, deleting every line that requires `DBIx::Class`, `DBIx::Class::Candy`, or `Test::DBIx::Class` (both the top-level `requires '...';` forms and the `on test` `requires '...';` forms). Leave all other deps (MooseX/DateTime/etc.) untouched. Verify none remain: `grep -nE "DBIx::Class|Test::DBIx::Class" /Users/jnapiorkowski/Desktop/Valiant/cpanfile` → no output.

- [ ] **Step 4: Regenerate the core README**

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && pod2markdown lib/Valiant.pm > README.mkdn'
```

- [ ] **Step 5: Verify core still green** (DBIC lane gone; everything else intact)

```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && prove -lr t 2>&1 | tail -4'
```
Expected: `Result: PASS`; file count drops by 12 (the `t/dbic/` files) from 74 to ≈62. `t/ancestors.t` still passes (it uses the retained `t/lib/locale/en.pl`).

- [ ] **Step 6: Commit, push, open PR**

```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add cpanfile README.mkdn
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Remove DBIx::Class integration (extracted to DBIx-Class-Valiant dist)\n\nDBIx::Class::Valiant now lives at https://github.com/jjn1056/DBIx-Class-Valiant.\nDrops lib/DBIx/Class/Valiant, t/dbic, the Example::Schema/Schema test schemas,\nand the DBIx::Class/DBIx::Class::Candy/Test::DBIx::Class deps. Core-shared\nt/lib/locale/en.pl and the unrelated t/lib/Example/HTML files are retained.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
git -C /Users/jnapiorkowski/Desktop/Valiant push -u origin remove-dbic-integration
gh pr create --repo jjn1056/Valiant --base main --head remove-dbic-integration \
  --title "Remove DBIx::Class integration (extracted to DBIx-Class-Valiant dist)" \
  --body "$(printf 'DBIx::Class::Valiant is now its own distribution: https://github.com/jjn1056/DBIx-Class-Valiant.\n\nRemoves lib/DBIx/Class/Valiant, t/dbic, the DBIC-only Example::Schema/Schema test schemas, and the DBIx::Class + DBIx::Class::Candy + Test::DBIx::Class deps from core. Core-shared t/lib/locale/en.pl (used by t/ancestors.t) and the unrelated t/lib/Example/HTML files are deliberately retained. Suite stays green.\n\nThis completes the plugin split: core Valiant + DBIx::Class::Valiant + DBIO::Valiant are now three distributions.\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)')"
```

- [ ] **Step 7: CHECKPOINT C — John reviews/merges the PR.**

---

## Checkpoints (gates)

- **A** — after Task 3: extracted repo green in isolation (before any GitHub action).
- **B** — before Task 5: creating/pushing the `jjn1056/DBIx-Class-Valiant` GitHub repo.
- **C** — after Task 6: core-cleanup PR up for review before merge.

## Out of scope (follow-ups)

- Repo-wide `.DS_Store` sweep in core + adding `.DS_Store` to core's `.gitignore` (~30 tracked files; the agent flagged it — separate hygiene PR).
- The `Util::Exception` copy-paste `=head1 NAME` + dead `_build_message` code (present in BOTH the DBIC and DBIO lanes — fix once, in both, together).
- `t/lib/Example/HTML*` dead code cleanup in core (unrelated to this split).
- CPAN releases of Valiant / DBIO::Valiant / DBIx::Class::Valiant.
