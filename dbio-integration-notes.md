# DBIO Integration Scope Notes

Working notes for porting `DBIx::Class::Valiant` to DBIO (https://codeberg.org/dbio/dbio),
the asynchronous DBIx::Class successor. Branch: `dbio-integration`.

Status: v1 port implemented (see docs/superpowers/plans/2026-07-07-dbio-valiant-port.md);
upstream follow-ups pending (bless _relationship_data/get_cache contract; row-level
update_async/delete_async when upstream adds them).

## Part 1: What DBIx::Class::Valiant actually depends on

Catalog of every DBIC API the current integration hooks into. This is the surface
area DBIO must provide (natively or via upstream patches) for a port to work.

### Components and their jobs

| Component | Lines | Job |
|---|---|---|
| `DBIx::Class::Valiant::Result` | 1387 | Row-level glue: filter-on-new, validate-on-insert/update, nested params (`accept_nested_for`), mark-for-deletion, recursive mutation |
| `DBIx::Class::Valiant::ResultSet` | 301 | `new_result` override (nested params, `__context`), `skip_validation`, `build` alias for FormBuilder |
| `DBIx::Class::Valiant::Validates` | 48 | Moo::Role over `Valiant::Validates`; prepends `DBIx::Class::Valiant::Validator` namespace; skips validate on `__valiant_add` rows |
| `DBIx::Class::Valiant::Validator::{Result,ResultSet,SetSize}` | ~470 | Nested validation: run child validations, import child errors into parent as `rel.attr` / `rel[idx].attr` |
| `DBIx::Class::Valiant::Result::HTML::FormFields` | 448 | Column `tags` metadata + per-column form-field/select/checkbox/radio resultset generators for FormBuilder |
| `DBIx::Class::Valiant::Util::Exception::*` | ~200 | TooManyRows, BadParameterFK, BadParameters |

### DBIC APIs used — class/metadata level

- **C3 component system**: `use base 'DBIx::Class'`, `load_components` (Valiant components MUST load before others), `next::method` overrides of `new`, `insert`, `update`, `new_result`, `register_column`, `many_to_many`.
- `mk_classdata` (Class::Accessor::Grouped) for `_m2m_metadata`, `auto_validation`, `_nested`, FormFields registries.
- `mk_group_accessors(simple => ...)` (used by `inject_attribute`, e.g. confirmation validators).
- `register_column($column, \%info)` override — extracts `validates`, `filters`, `tag`/`tags` keys from column info hashes.
- `many_to_many` override — records m2m metadata (DBIC has no m2m introspection; Valiant builds its own registry).
- `DBIx::Class::Candy::Exports` (`export_methods`) — DSL support for DBIC::Candy users.

### DBIC APIs used — row (result) level

- `new` (via new_result), `insert`, `update`, `delete`, `update_or_insert`, `get_from_storage`, `in_storage`, `id`.
- Column access: `get_column`, `get_columns`, `set_column`, `set_inflated_columns`, `has_column`, `columns`, `is_column_changed`, `is_changed`.
  - `read_attribute_for_validation` deliberately reads *uninflated* column values (`get_column`) to avoid inflation errors on unvalidated data (e.g. bad dates + DateTime inflator).
- Relationship access: `has_relationship`, `relationship_info` (uses `attrs.accessor` ∈ single/multi/filter, `attrs.join_type`, and parses `cond` `foreign.x => self.y` pairs for FK/PK mapping and tamper checks), `new_related`, `find_related`, `find_or_new_related`, `set_from_related`, `related_resultset`.
- `result_source` → `relationships`, `relationship_info`, `reverse_relationship_info`, `primary_columns`, `unique_constraints`, `related_source`, `resultset`, `has_column`, `name`, `schema`.
- **Resultset cache**: `related_resultset($rel)->get_cache` / `->set_cache(\@rows)` — the backbone of nested create/update: pending related rows live in the cache until mutation.
- **Private DBIC row internals** (fragile; will need DBIO equivalents or public API):
  - `$row->{_relationship_data}` — read AND written directly
  - `$row->{_inflated_column}` — written for `filter`-accessor rels
  - `$row->{related_resultsets}` — cached/restored around `update_or_insert`
  - `$row->_storage_ident_condition` — PK-completeness check before `get_from_storage`
- Valiant's own private row flags (hash-slot state on the row): `__valiant_kiss_of_death` (marked for deletion), `__valiant_is_pruned`, `__valiant_allow_destroy`, `__valiant_donot_insert`, `__valiant_add`, `__VALIANT_CREATE_ARGS`, `__valiant_related_resultset`, `_valiant_nested_info`.

### DBIC APIs used — resultset level

- `new_result` override (strips `__context` + nested rel params before delegating), `create` (inherited: new_result + insert), `all`, `next`, `reset`, `single`, `find`, `get_cache`, `set_cache`, `result_class`, `result_source`.
- Transactions: `schema->txn_scope_guard` (update path), `schema->txn_begin/txn_commit/txn_rollback` (`set_recursively` rollback_on_invalid).

### Control flow contracts (the semantics a port must preserve)

1. **Create**: `$rs->create({ %cols, %nested, __context => ... })` → `new_result` strips context + nested params, builds related rows recursively into resultset caches, then `insert` runs filters + validations first; **if invalid, the insert silently does not happen** and the (not-in-storage) row is returned carrying `->errors`. Caller checks `$row->valid` / `->invalid`.
2. **Update**: same shape; nested params merged into cached related rows; validation before mutation; all mutation wrapped in a `txn_scope_guard`; rows marked `_delete` are deleted (only if `allow_destroy`), removed rows pruned recursively.
3. **Nested params** accept arrays (API style) or numbered hashes (CGI form style), `_delete`/`_add`/`_nop`/`_restore`/`_action` pseudo-columns, FK tamper checks (BadParameterFK), `limit`, `reject_if`, `update_only`, `find_with_uniques` options.
4. **Auto-validation contexts**: `create` and `update` contexts pushed automatically; user contexts via `__context`.
5. **Errors aggregate upward**: child row errors are imported into the parent's `Valiant::Errors` with dotted/indexed attribute paths (`profile.first_name`, `credit_cards[0].number`).
6. Filters run on `new` (column values only, uninflated).
7. `is_unique` validator support does a `$source->resultset->single({col => $val})` lookup, skipped when value unchanged on in-storage rows.
8. FormBuilder integration expects: `$rs->build` (= `new_result({})`), `$row->read_attribute_for_html`, `model_name` (Valiant::Naming), `errors`, `in_storage`, `is_marked_for_deletion`, and the resultset-cache round-trip so redisplayed forms show pending (invalid) nested rows.

## Part 2: DBIO architecture (vs DBIx::Class)

Checkout: `~/Desktop/dbio` (https://codeberg.org/dbio/dbio). Verified facts, not assumptions:

- **DBIO is a fork of DBIx::Class, not a reimplementation.** README: "Most code works
  with a namespace search-and-replace" (`DBIx::Class::` → `DBIO::`). Released to CPAN
  as `GETTY/DBIO-0.900000`; drivers are separate dists (`DBIO::SQLite` 0.900000 on CPAN,
  also PostgreSQL/MySQL/DuckDB + extracted legacy drivers).
- **Perl floor**: cpanfile requires perl 5.008001; core avoids modern syntax (signatures
  only via opt-in `DBIO::Candy -experimental`). No conflict with Valiant's 5.20 floor.
- **Same component system**: `DBIO::Componentised` is literally
  `use base 'Class::C3::Componentised'` — identical to DBIC. `load_components` +
  `next::method` overrides work unchanged. Row-level core components use
  `use base 'DBIO::Row'`; the minimal componentised base is `DBIO::Base`
  (provides `mk_classdata`/`mk_classaccessor`).
- **Candy is in core** with `DBIO::Candy::Exports` providing the *same*
  `export_methods` / `export_method_aliases` API as `DBIx::Class::Candy::Exports`.
  New `DBIO::Cake` DDL-ish DSL also exists (also exposes `many_to_many`).
- **DBIx::Class::Helpers merged into core** → `many_to_many` natively records
  `_m2m_metadata` classdata with the exact key set Valiant's override builds
  (accessor, relation, foreign_relation, attrs, rs_method, add/set/remove_method).
- **ADR 0023**: `relationship_info->{source}` and `->{attrs}{accessor}` are now a
  *documented public contract* (multi / single / filter). `belongs_to` accessor logic
  is byte-for-byte DBIC's: `filter` only when rel name collides with a column, else
  `single`.
- **SQL::Abstract (modern) replaces Classic; SQL::Translator removed** (native
  test-deploy-and-compare per driver). Irrelevant to validation glue, but relevant to
  test setup: schema deploy for tests uses the driver's native `deploy`.
- **New orthogonal features** (no interaction expected, worth watching): Replicated
  storage in core, ChangeLog schema component, Timestamp component in core,
  `quote_names` ON by default (departure from DBIC).
- **Testing**: core tests run against `DBIO::Test::Storage` (fake storage, no real DB);
  real-DB testing lives in driver dists. For Valiant integration tests we should use
  real SQLite via `DBIO::SQLite` (in-memory), consistent with our no-mocks-in-e2e rule.

### The async model (ADRs 0014 / 0030 / 0031)

**RELEASE-GAP CORRECTION (found during implementation, 2026-07-07):** the
per-connection mode subsystem described below (ADRs 0028-0031: `{async => ...}`
at connect, mode registry, `Row::insert_async`, `DBIO::Future::Immediate`)
exists ONLY in the dev checkout — it postdates the v0.900000 tag (2026-06-23)
and is in no CPAN release. CPAN DBIO 0.900000 carries the older ADR-0014
semantics: `*_async` always silently degrades to the synchronous op wrapped in
an immediately-resolved `DBIO::Test::Future`. Consequence: on released DBIO,
`create_async` runs the composed synchronous `create`, so DBIO::Valiant
validation already gates it — the live-backend bypass we designed the
`insert_async` override for cannot occur. Decision (John): target released
DBIO for v1; the override + its backend test are deferred (fully specified in
the plan, Task 14) until DBIO ships the subsystem; `t/dbio/async-pg.t` carries
a `register_async_mode` capability skip-guard. Pinned by
`t/dbio/async-immediate.t` (9 assertions) against 0.900000.

- Async is an **explicit per-connection mode**: `Schema->connect($dsn, $u, $p,
  { async => 'forked' | 'future_io' | 'ev' | 'immediate' })`. Schema classes carry no
  async declaration; one class can have sync and several async instances side by side.
- Mode registry (ADR 0030):
  - `forked` (dist `dbio-forked`) — works with **any** driver, **no event loop** (fork per query).
  - `future_io` (dist `dbio-async`) — **loop-agnostic**: drives the DBD's own async
    binding (DBD::Pg, DBD::mysql) through `Future::IO`; the loop is chosen by installing
    a `Future::IO::Impl::*` adapter (IO::Poll default; IO::Async / AnyEvent / Mojo / UV /
    Glib optional).
  - `ev` — the only *native-client*, loop-bound mode (EV::Pg / EV::MariaDB via per-driver
    EV add-on dists).
  - `immediate` — the former silent sync-degrade, now explicit (`DBIO::Future::Immediate`).
- `*_async` on a **sync** instance croaks. No auto-fallback, no silent degrade.
- **SQLite and async**: SQLite is an in-process library with no async binding, so
  `future_io` and `ev` are unavailable — `forked` is the only real-async mode for it,
  and `DBIO::Forked`'s POD names SQLite explicitly as a target. Caveat verified in
  dbio-forked's own `t/05-sqlite-live.t`: the forked child *reconnects fresh* per
  query, so it requires a **file-backed** SQLite DB (`sqlite_use_file => 1`) —
  `:memory:` cannot work (a fresh child connection sees an empty database). The
  `DBIO::SQLite` dist ships a `DBIO::SQLite::Test->init_schema` helper supporting
  exactly this pattern.
- `DBIO::Future` is a duck-type contract (`then`/`catch`/`get`/`is_ready`/`is_failed`);
  `then` callbacks may return plain values (auto-wrapped).
- RS/Row async surface: `all_async`/`first_async`/`single_async`/`count_async`/
  `create_async` (ResultSet) and `insert_async` (Row); `create_async` =
  `new_result->insert_async`. **No row-level `update_async`/`delete_async` yet**
  (deliberately deferred upstream — "no caller").
- **The fact that decides our design** (`DBIO::Row::insert_async`, verified in source):
  if `$row->{_relationship_data}` or `$row->{_inflated_column}` is non-empty, the
  backend path *falls back to synchronous composed `$self->insert`* ("related-object
  multi-create is a multi-statement transactional cascade… run it synchronously").
  Under `immediate` mode it likewise runs sync `insert`. Only the simple,
  no-relationship-data insert goes straight to `$backend->insert_async`, bypassing the
  composed sync `insert`. Sync ops remain callable on async instances (the fallback
  depends on it).

## Part 3: API map — DBIC::Valiant needs → DBIO equivalents / gaps

Every API from Part 1 was checked against the DBIO source. Status:

| DBIC dependency | DBIO status |
|---|---|
| C3 components, `load_components`, `next::method` | ✅ identical (`Class::C3::Componentised`) |
| `mk_classdata`, `mk_group_accessors` | ✅ `DBIO::Base` |
| `DBIx::Class::Candy::Exports` `export_methods` | ✅ `DBIO::Candy::Exports`, same API |
| `many_to_many` metadata capture | ✅ **native** `_m2m_metadata` in core — Valiant's override shrinks to nothing (see gaps) |
| Row: `new/insert/update/delete/update_or_insert/get_from_storage/discard_changes/copy` | ✅ all present, same shapes (`create` = `new_result->insert`) |
| Row columns: `get_column(s)/set_column/set_inflated_columns/is_changed/is_column_changed/has_column_loaded` | ✅ |
| `register_column` override point | ✅ |
| Rel helpers: `new_related/find_related/find_or_new_related/set_from_related/related_resultset/update_or_create_related` | ✅ `DBIO::Relationship::Base` |
| ResultSource introspection: `relationships/relationship_info/reverse_relationship_info/primary_columns/unique_constraints/related_source/has_column/resultset` | ✅ — and `relationship_info` keys are now *public contract* (ADR 0023) |
| ResultSet: `new_result` override point, `find/single/all/next/reset`, `get_cache/set_cache` | ✅ |
| Transactions: `txn_scope_guard`, `txn_begin/commit/rollback` | ✅ Schema + Storage |
| Private internals: `_relationship_data`, `_inflated_column`, `related_resultsets`, `_storage_ident_condition` | ✅ all retained (still private — see upstream candidates) |
| `isa('DBIx::Class::Row')` check in `set_recursively` | rename → `DBIO::Row` |
| Rest of Valiant (FormBuilder etc.) | ✅ duck-typed (`can('primary_columns')`, `->next`, `->errors`) — no DBIC coupling outside `lib/DBIx/` |

### Genuinely new work (not covered by rename-port)

1. **`insert_async` override** in `DBIO::Valiant::Result`: validate → if invalid,
   return a resolved Future carrying the errored row *without* inserting; else
   `next::method`. Needed because the simple no-nested async insert bypasses the sync
   `insert` where our validation hook lives. Nested async creates already funnel into
   the sync composed `insert` (upstream fallback), so full nested validation rides for
   free.
2. **Test harness**: `Test::DBIx::Class` is DBIC-only. Need a DBIO test setup —
   `DBIO::SQLite` in-memory + native `deploy`, plus a DBIO port of the test schema in
   `t/lib` (Example::Schema has ~15 result classes) and a `t/dbio/` mirror of the 10
   `t/dbic/*.t` files.
3. **m2m simplification**: drop the `many_to_many` override; DBIO records the metadata
   itself. The generated `${rel}_pks` helper appears **unused** anywhere in lib/ or t/
   — propose dropping it in the DBIO port (confirm: it is technically public surface
   in the DBIC version).
4. **Exception classes**: port `DBIx::Class::Valiant::Util::Exception::*` →
   `DBIO::Valiant::Util::Exception::*` (mechanical).
5. **Async semantics of validation itself**: `validate` is synchronous. Validators that
   hit the DB (`is_unique` does `$source->resultset->single(...)`) will block the event
   loop on an async connection. v1: accept + document (validation is CPU-bound except
   Unique). Later: an async validation API (validators returning futures) — big design,
   out of scope for v1.

### Upstream patch candidates (none blocking so far)

- **Bless the row/cache internals Valiant needs** the way ADR 0023 blessed
  `relationship_info`: `_relationship_data`, resultset `get_cache`/`set_cache`
  semantics, `_storage_ident_condition`. Worth proposing as a DBIO ADR/karr ticket so
  the contract can't drift under us.
- **Row-level `update_async`/`delete_async`** — upstream says "same pattern when
  wanted"; we'd want them eventually for full async CRUD parity, plus the async
  recursive cascade they explicitly deferred (ADR 0031). Not needed for v1 because the
  cascade path is sync-by-design upstream.
- Driver `insert_async` returned-columns hashref shape is already a tracked upstream
  ticket (ADR 0031 §3) — affects us only on real async backends.

## Part 4: Design questions for John & proposed work breakdown

### Questions to settle before implementation

**DECIDED 2026-07-07 (John):**
1. Packaging — **inside the Valiant dist** (mirrors DBIx::Class::Valiant; DBIO +
   DBIO::SQLite as develop/test deps only).
2. Code sharing — **straight copy-port**, two parallel trees; revisit extraction later.
3. `${rel}_pks` helper — **drop** in the DBIO port.
4. v1 async scope — as proposed (sync + immediate fully supported; `insert_async`
   validation override; validation itself stays synchronous).
5. Test lanes — **in-memory SQLite (sync + immediate mode)** plus an **env-guarded
   PostgreSQL lane** for real non-blocking (`future_io`/`ev`) coverage. Forked-mode
   file-backed SQLite lane: skipped for v1.

Original questions kept below for the record.

1. **Packaging**: `DBIO::Valiant` inside the Valiant dist (mirroring
   `DBIx::Class::Valiant`), or a separate `DBIO-Valiant` dist (matching the DBIO
   ecosystem's dist-per-concern pattern, and letting it depend on DBIO 0.900000 without
   burdening Valiant's deps)? Note: DBIO + DBIO::SQLite would otherwise join Valiant's
   test deps.
2. **Code sharing vs copy-port**: the two glue layers will be ~95% identical today.
   Options: (a) straight copy-port, two parallel trees (safe, DBIO is young and will
   drift); (b) extract a shared role/base with thin DBIC/DBIO adapters (less
   duplication, but couples us to two ORMs' internals through one abstraction).
   Recommendation: (a) for v1, revisit extraction once DBIO::Valiant is stable — but
   this is an architecture call to make together.
3. **`${rel}_pks` helper**: drop from the DBIO port (unused)?
4. **v1 async scope**: sync + `immediate` mode fully supported; real-async simple
   creates validated via the `insert_async` override; async `update` doesn't exist
   upstream so nothing to do. Agreed?
5. **Test strategy**: real SQLite via `DBIO::SQLite` (recommended; no mocks). For the
   async lane: `immediate` mode runs on in-memory SQLite (covers the `insert_async`
   validation-gating logic and Future shapes); a real `forked`-mode lane needs
   **file-backed** SQLite (upstream's own pattern — `:memory:` can't cross the fork).
   Real `future_io`/`ev` coverage would need an env-guarded PostgreSQL/MySQL lane —
   defer?

### Proposed work breakdown (each step commit-able)

1. Add DBIO + DBIO::SQLite to develop/test deps; confirm they install under
   perlbrew perl-5.40.0@default.
2. Port `DBIO::Valiant::Validates` + `Util::Exception::*` (mechanical) with POD.
3. Port `DBIO::Valiant::Result` (drop m2m override, keep everything else; adjust
   namespaces) + `DBIO::Valiant::ResultSet`.
4. Port the three validators (`Result`, `ResultSet`, `SetSize`) — only namespace
   changes expected.
5. Port `Result::HTML::FormFields` (namespace-only).
6. DBIO test schema under `t/lib` + `t/dbio/` test files mirroring `t/dbic/`,
   TDD-style: port one test file, make it pass, commit, repeat.
7. New: `insert_async` validation override + async tests (immediate mode first).
8. POD: `DBIO::Valiant` main doc (adapted from `DBIx::Class::Valiant`).
9. Sync with upstream: file the "bless the internals" proposal; report anything we
   trip over as codeberg issues/patches.

### Open observations (pre-existing quirks noticed while reading, NOT port work)

- `set_m2m_related_from_params` / `set_multi_related_from_params` use `next` outside a
  loop (Result.pm:583, 625) — "Exiting subroutine via next" territory; dead `die`
  statements after them.
- `set_single_related_from_params` has a doubled `->find($params)` / `->find(\%pk)`
  call (Result.pm:950-951) with a TODO acknowledging it.
- `insert` context push has a `## ?? IS this a bug? Why update` comment (Result.pm:138).
- These behave identically under DBIO; flagging so a port doesn't silently "fix" or
  fork behavior.

### Pre-existing bugs found during coverage deepening (Task 17)

- **`allow_destroy` never takes effect on single relations** (`belongs_to` /
  `might_have` / `has_one`). `set_single_related_from_params` reads the option
  with `my $allow_destroy = $nested{allow_destroy};` — but `%nested` is keyed
  by *relation name*, so the lookup is always undef and
  `__valiant_allow_destroy` is never set on the related result. Since
  `mark_for_deletion` is a guarded no-op without that flag, submitting
  `_delete => 1` (or `_action => 'delete'`) inside a nested *single* relation
  silently does nothing, even when the schema declares
  `accept_nested_for($rel, { allow_destroy => 1 })` (as
  `Schema::Nested::Result::PersonRole` does for `role`). The correct read
  would be `$nested{$related}{allow_destroy}` (mirroring
  `_related_allow_destroy`, which the *multi*-relation path uses and which
  works). Locations: `lib/DBIO/Valiant/Result.pm:852` and, identically,
  `lib/DBIx/Class/Valiant/Result.pm:888`.

  DBIC-lane repro (Test::DBIx::Class + `Schema::Nested`): create a Person
  with one person_role, reload with `prefetch => { person_roles => 'role' }`,
  then `$person_role->update({ role => { id => $role_id, _delete => 1 } })` —
  the role row stays in storage and `is_marked_for_deletion` remains false in
  BOTH lanes, so this predates the port. Per the port ground rules no
  `lib/` code was changed; the planned "single-relation nested destroy"
  test block was dropped from Task 17 (multi-relation `allow_destroy`,
  where the option works, is covered in `t/dbio/nested-options.t` and
  `t/dbio/pseudo-params.t`). Fix upstream in both lanes together, with a
  test, as post-plan work.
