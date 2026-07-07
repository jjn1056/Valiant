# DBIO::Valiant Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port `DBIx::Class::Valiant` to `DBIO::Valiant` inside the Valiant dist, so DBIO (the async fork of DBIx::Class) result/resultset classes get the same Valiant validation glue, including validation gating on the async `create_async`/`insert_async` path.

**Architecture:** Straight copy-port of the 8 glue modules from `lib/DBIx/Class/Valiant/` to `lib/DBIO/Valiant/` (two parallel trees; the DBIC tree is NEVER modified). Three deliberate deltas from the DBIC version: (1) drop the `many_to_many` override and its generated `${rel}_pks` helper — DBIO records `_m2m_metadata` natively with the identical key set; (2) add an `insert_async` override that gates the live-backend fast path on validation; (3) namespace renames. Tests mirror `t/dbic/` as `t/dbio/`, running on real in-memory SQLite (`DBIO::SQLite`), with an env-guarded PostgreSQL lane for real non-blocking async.

**Tech Stack:** Perl (5.20-compatible syntax in `lib/`), Moo/Moo::Role, DBIO 0.900000 + DBIO::SQLite 0.900000 (CPAN: GETTY), Test::Most, Test::Lib, Test::Needs, Dist::Zilla packaging (deps via cpanfile).

**Background reading (do not skip):** `dbio-integration-notes.md` at the repo root — Part 1 catalogs every DBIC API the glue uses; Part 2/3 verify the DBIO equivalents. A DBIO checkout for reference is at `~/Desktop/dbio` (v0.900000 + main).

## Global Constraints

- **Branch**: all work happens on the existing `dbio-integration` branch.
- **Perl environment**: NEVER run system perl. EVERY perl/prove/cpanm command in this plan must be run as: `bash -c 'source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && <command>'`. Steps below write the bare `<command>`; always wrap it.
- **Syntax floor**: code in `lib/` must run on Perl 5.20 — no `use feature`, no subroutine signatures, no postfix deref. Match the style of the DBIC source file you are porting, byte-for-byte where possible.
- **The DBIC tree is read-only**: never edit anything under `lib/DBIx/`, `t/dbic/`, `t/lib/Example/` (except copying FROM it), `t/lib/Schema/`.
- **The Standard Rename** (referenced by name in tasks below) — apply to a freshly copied file, in this order:
  1. `perl -pi -e "s/use base 'DBIx::Class';/use base 'DBIO::Base';/"` (the bare component base; must run BEFORE step 2)
  2. `perl -pi -e 's/DBIx::Class/DBIO/g'` (handles `DBIx::Class::Valiant`→`DBIO::Valiant`, `DBIx::Class::Row`→`DBIO::Row`, `DBIx::Class::ResultSet`→`DBIO::ResultSet`, `DBIx::Class::Schema`→`DBIO::Schema`, `DBIx::Class::Core`→`DBIO::Core`, `DBIx::Class::Candy::Exports`→`DBIO::Candy::Exports`, `DBIx::Class::ResultClass::HashRefInflator`→`DBIO::ResultClass::HashRefInflator`, and all POD links)
  3. Verify: `grep -c "DBIx" <file>` must print `0`.
- **POD**: every ported module keeps its POD (renamed by the Standard Rename); any NEW public method (e.g. `insert_async`) gets POD in the same commit. Undocumented public surface is a release blocker.
- **Test failures are findings**: when a ported test fails, find the root cause. If the root cause is a genuine DBIC↔DBIO behavior difference, STOP, record it in `dbio-integration-notes.md`, and raise it with John before working around anything. Never delete or weaken a test assertion to get green.
- **Commit after every task** (and at the intermediate points marked below). Commit messages end with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- **Coverage mandate (from John)**: the DBIC-era test depth is known-thin; the DBIO lane should end up with BETTER coverage than the DBIC lane, not equal. Ported test files (Tasks 6-13) stay faithful mirrors — do NOT add assertions to them. Instead, while porting, append every under-tested behavior you notice to `t/dbio/COVERAGE-GAPS.md` (one bullet per gap: feature, where it lives, why you think it's untested). Task 17 turns that list into new dedicated test files.

---

### Task 1: Test dependencies + environment gate

**Files:**
- Modify: `cpanfile` (the `on test => sub {...}` block, lines ~36-52)
- Create: `t/dbio/00-env.t`

**Interfaces:**
- Produces: a working DBIO + DBIO::SQLite install; the connect/deploy pattern (`connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 })` then `$schema->deploy`) that every later test task reuses.

- [ ] **Step 1: Add DBIO deps to cpanfile test block**

In `cpanfile`, inside the existing `on test => sub { ... }` block, add:

```perl
  requires 'DBIO' => '0.900000';
  requires 'DBIO::SQLite' => '0.900000';
```

- [ ] **Step 2: Install them**

Run: `cpanm --notest DBIO DBIO::SQLite`
Expected: both report `Successfully installed`. If either fails to install, STOP and report the build log to John — do not hunt for workarounds solo.

- [ ] **Step 3: Write the environment gate test**

Create `t/dbio/00-env.t`:

```perl
use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

{
  package Env00::Schema::Result::Widget;

  use base 'DBIO::Core';

  __PACKAGE__->table("widget");
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 24 },
  );
  __PACKAGE__->set_primary_key("id");

  package Env00::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Widget => 'Env00::Schema::Result::Widget');
}

ok my $schema = Env00::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 }),
  'connected in-memory SQLite via DBIO';
$schema->deploy;

ok my $widget = $schema->resultset('Widget')->create({ name => 'test' }), 'created a row';
ok $widget->id, 'autoinc PK came back';
is $schema->resultset('Widget')->count, 1, 'count is 1';

done_testing;
```

- [ ] **Step 4: Run it**

Run: `prove -lv t/dbio/00-env.t`
Expected: PASS (4 oks). If `deploy` fails, capture the exact error and STOP (native deploy is a DBIO::SQLite feature; a failure here is an upstream finding).

- [ ] **Step 5: Commit**

```bash
git add cpanfile t/dbio/00-env.t
git commit -m "Add DBIO test deps and environment gate test

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Exception classes

**Files:**
- Create: `lib/DBIO/Valiant/Util/Exception.pm` (from `lib/DBIx/Class/Valiant/Util/Exception.pm`)
- Create: `lib/DBIO/Valiant/Util/Exception/TooManyRows.pm` (from `.../Exception/TooManyRows.pm`)
- Create: `lib/DBIO/Valiant/Util/Exception/BadParameterFK.pm` (from `.../Exception/BadParameterFK.pm`)
- Create: `lib/DBIO/Valiant/Util/Exception/BadParameters.pm` (from `.../Exception/BadParameters.pm`)
- Test: `t/dbio/exceptions.t`

**Interfaces:**
- Produces: `DBIO::Valiant::Util::Exception::TooManyRows->throw(limit =>, attempted =>, related =>, me =>)`, `...::BadParameterFK->throw(fk_field =>, fk_value =>, pk_field =>, pk_value =>, related =>, me =>)`, `...::BadParameters->throw(related =>, me =>)` — consumed by Task 3's Result/ResultSet components. All are Moo classes extending `Valiant::Util::Exception` (which provides `->throw` and a `message` built by `_build_message`).

- [ ] **Step 1: Copy and rename**

```bash
mkdir -p lib/DBIO/Valiant/Util/Exception
cp lib/DBIx/Class/Valiant/Util/Exception.pm lib/DBIO/Valiant/Util/Exception.pm
cp lib/DBIx/Class/Valiant/Util/Exception/TooManyRows.pm lib/DBIO/Valiant/Util/Exception/TooManyRows.pm
cp lib/DBIx/Class/Valiant/Util/Exception/BadParameterFK.pm lib/DBIO/Valiant/Util/Exception/BadParameterFK.pm
cp lib/DBIx/Class/Valiant/Util/Exception/BadParameters.pm lib/DBIO/Valiant/Util/Exception/BadParameters.pm
```

Apply the Standard Rename to each of the 4 new files. (None of them contain `use base 'DBIx::Class'`, so rename step 2 is the only one that will change anything.)

- [ ] **Step 2: Write the failing test**

Create `t/dbio/exceptions.t`:

```perl
use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

use_ok 'DBIO::Valiant::Util::Exception';
use_ok 'DBIO::Valiant::Util::Exception::TooManyRows';
use_ok 'DBIO::Valiant::Util::Exception::BadParameterFK';
use_ok 'DBIO::Valiant::Util::Exception::BadParameters';

{
  eval {
    DBIO::Valiant::Util::Exception->throw(msg => 'test message');
  };
  ok my $err = $@, 'base exception thrown';
  ok $err->isa('DBIO::Valiant::Util::Exception'), 'correct class';
  is $err->message, 'test message', 'message built from msg attribute';
}

{
  eval {
    DBIO::Valiant::Util::Exception::TooManyRows->throw(
      limit => 2, attempted => 3, related => 'credit_cards', me => 'person');
  };
  ok my $err = $@, 'TooManyRows thrown';
  ok $err->isa('DBIO::Valiant::Util::Exception::TooManyRows'), 'correct class';
  like $err->message, qr/credit_cards/, 'message names the relationship';
  like $err->message, qr/attempted 3/, 'message names the attempted count';
}

done_testing;
```

Note: `BadParameterFK` / `BadParameters` `_build_message` implementations may call methods on their `me` attribute (a row object at real call sites) — the `use_ok` checks cover loadability; their message formatting is exercised end-to-end by the nested tests in Tasks 8-11. Do not construct them with fake row objects here.

- [ ] **Step 3: Run test to verify current state**

Run: `prove -lv t/dbio/exceptions.t`
Expected: PASS (the implementation was created in Step 1; this validates the rename produced loadable, working classes). If any `use_ok` fails, read the error — a leftover `DBIx` string means the Standard Rename was misapplied; re-run its verify grep.

- [ ] **Step 4: Commit**

```bash
git add lib/DBIO/Valiant/Util t/dbio/exceptions.t
git commit -m "Port Valiant exception classes to DBIO namespace

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Validates role

**Files:**
- Create: `lib/DBIO/Valiant/Validates.pm`
- Test: `t/dbio/validates-role.t`

**Interfaces:**
- Produces: `DBIO::Valiant::Validates` — a Moo::Role over `Valiant::Validates` that (a) prepends `DBIO::Valiant::Validator` to `default_validator_namespaces` and (b) skips `validate` for rows flagged `{__valiant_add}`. Consumed by Task 4's `DBIO::Valiant::Result` via `with`.

- [ ] **Step 1: Write the file**

Create `lib/DBIO/Valiant/Validates.pm` with exactly this content (hand-written equivalent of the DBIC original with the Standard Rename applied — the file is small enough to write directly):

```perl
package DBIO::Valiant::Validates;

use Moo::Role;
use Valiant::I18N;
use Scalar::Util;

with 'Valiant::Validates';

around default_validator_namespaces => sub {
  my ($orig, $self, @args) = @_;
  return 'DBIO::Valiant::Validator', $self->$orig(@args);
};

around validate => sub {
  my ($orig, $self, @args) = @_;
  return if $self->{__valiant_add};
  return $self->$orig(@args);
};

1;

=head1 NAME

DBIO::Valiant::Validates - Add Valiant to DBIO

=head1 DESCRIPTION

This is a role which extends L<Valiant::Validates> so that is finds validators
under the L<DBIO::Valiant::Validator> namespace.  It adds this namespace
to the top of the call list, that way we can if needed override core validators
with versions that work properly under L<DBIO>.

You shouldn't need to use this code directly yourself, it gets added automatically
for you.

=head1 SEE ALSO

See L<Valiant>, L<DBIO::Valiant>

=head1 AUTHOR

See L<Valiant>.

=head1 COPYRIGHT & LICENSE

See L<Valiant>.

=cut
```

- [ ] **Step 2: Write the test**

Create `t/dbio/validates-role.t`:

```perl
use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

{
  package Local::TestRow;

  use Moo;
  with 'DBIO::Valiant::Validates';

  has name => (is=>'ro');

  __PACKAGE__->validates(name => (presence => 1));
}

{
  my $obj = Local::TestRow->new(name => undef);
  is +($obj->default_validator_namespaces)[0], 'DBIO::Valiant::Validator',
    'DBIO validator namespace searched first';
  $obj->validate;
  ok $obj->errors->size, 'presence validation ran and failed';
}

{
  my $obj = Local::TestRow->new(name => undef);
  $obj->{__valiant_add} = 1;
  $obj->validate;
  is $obj->errors->size, 0, 'validate is a no-op for __valiant_add rows';
}

done_testing;
```

- [ ] **Step 3: Run it**

Run: `prove -lv t/dbio/validates-role.t`
Expected: PASS (3 assertions).

- [ ] **Step 4: Commit**

```bash
git add lib/DBIO/Valiant/Validates.pm t/dbio/validates-role.t
git commit -m "Port DBIO::Valiant::Validates role

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Result + ResultSet components and the three validators

**Files:**
- Create: `lib/DBIO/Valiant/Result.pm` (from `lib/DBIx/Class/Valiant/Result.pm`)
- Create: `lib/DBIO/Valiant/ResultSet.pm` (from `lib/DBIx/Class/Valiant/ResultSet.pm`)
- Create: `lib/DBIO/Valiant/Validator/Result.pm` (from `lib/DBIx/Class/Valiant/Validator/Result.pm`)
- Create: `lib/DBIO/Valiant/Validator/ResultSet.pm` (from `lib/DBIx/Class/Valiant/Validator/ResultSet.pm`)
- Create: `lib/DBIO/Valiant/Validator/SetSize.pm` (from `lib/DBIx/Class/Valiant/Validator/SetSize.pm`)
- Test: `t/dbio/component.t`

These five files are one reviewable unit: `accept_nested_for` in Result.pm auto-registers the Result/ResultSet validators (resolved through the `DBIO::Valiant::Validator` namespace from Task 3), so the components don't function without them.

**Interfaces:**
- Consumes: `DBIO::Valiant::Validates` (Task 3), the exception classes (Task 2).
- Produces: DBIO components loadable as `__PACKAGE__->load_components('Valiant::Result')` on `DBIO::Core`-derived result classes and `load_components('Valiant::ResultSet')` on `DBIO::ResultSet`-derived resultset classes (component resolution: `component_base_class` is `'DBIO'`, verified in DBIO::Base line 53). Public surface identical to the DBIC versions MINUS `many_to_many`/`${rel}_pks` (dropped — see Step 2), PLUS nothing yet (`insert_async` comes in Task 14).

- [ ] **Step 1: Copy and rename**

```bash
mkdir -p lib/DBIO/Valiant/Validator
cp lib/DBIx/Class/Valiant/Result.pm lib/DBIO/Valiant/Result.pm
cp lib/DBIx/Class/Valiant/ResultSet.pm lib/DBIO/Valiant/ResultSet.pm
cp lib/DBIx/Class/Valiant/Validator/Result.pm lib/DBIO/Valiant/Validator/Result.pm
cp lib/DBIx/Class/Valiant/Validator/ResultSet.pm lib/DBIO/Valiant/Validator/ResultSet.pm
cp lib/DBIx/Class/Valiant/Validator/SetSize.pm lib/DBIO/Valiant/Validator/SetSize.pm
```

Apply the Standard Rename to each of the 5 files. Note `Result.pm` contains `use base 'DBIx::Class';` — rename step 1 turns it into `use base 'DBIO::Base';`. The `use DBIx::Class::Candy::Exports;` line becomes `use DBIO::Candy::Exports;` via step 2 (verified: same `export_methods` API upstream).

- [ ] **Step 2: Delete the many_to_many override from lib/DBIO/Valiant/Result.pm**

DBIO natively records m2m metadata (`DBIO::Relationship::ManyToMany::many_to_many` stores `_m2m_metadata` with the same keys). Delete this entire sub (it appears right after the `mk_classdata` block; shown here post-rename):

```perl
sub many_to_many {
  my $class = shift;
  my ($meth_name, $link, $far_side) = @_;
  my $store = $class->_m2m_metadata;
  warn("You are overwritting another relationship's metadata")
    if exists $store->{$meth_name};

  my $attrs = {
    accessor => $meth_name,
    relation => $link, #"link" table or immediate relation
    foreign_relation => $far_side, #'far' table or foreign relation
    (@_ > 3 ? (attrs => $_[3]) : ()), #only store if exist
    rs_method => "${meth_name}_rs",      #for completeness..
    add_method => "add_to_${meth_name}",
    set_method => "set_${meth_name}",
    remove_method => "remove_from_${meth_name}",
  };

  my $pk_meth = qq[
    package $class;

    sub ${meth_name}_pks {
      my \$self = shift;
      my \@pks = \$self->related_resultset("${link}")->related_resultset("${far_side}")->result_source->primary_columns;
      return map {
        my \$row = \$_;
        +{ map { \$_ => \$row->\$_ } \@pks };
      } \$self->\$meth_name->all;
    }
  ];

  eval $pk_meth;
  die $@ if $@;

  #inheritable data workaround
  $class->_m2m_metadata({ $meth_name => $attrs, %$store});
  $class->next::method(@_);
}
```

KEEP the line `__PACKAGE__->mk_classdata( _m2m_metadata => {} );` — it guarantees `_m2m_metadata` is always defined (the component's inherited accessor is what DBIO's native `many_to_many` will store into, because it declares the classdata only `unless $class->can('_m2m_metadata')`). Add this comment above the kept line so the reason survives:

```perl
# DBIO's native many_to_many records the same _m2m_metadata this component
# needs; declaring it here (empty) guarantees the accessor always exists,
# and native many_to_many stores into it via the inherited accessor.
```

- [ ] **Step 3: Check the insert_or_update alias**

`lib/DBIO/Valiant/ResultSet.pm` (`set_recursively`) calls `$new_result->insert_or_update`. Verified: DBIO::Row keeps the alias (`sub insert_or_update { shift->update_or_insert(@_) }`, `~/Desktop/dbio/lib/DBIO/Row.pm:1533`). No edit needed — this step is a verification only:

Run: `grep -n "insert_or_update" lib/DBIO/Valiant/ResultSet.pm`
Expected: 2 matches (the two call sites), unchanged.

- [ ] **Step 4: Write the component test**

Create `t/dbio/component.t`:

```perl
use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

{
  package C1::Schema::Result::Album;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->resultset_class('C1::Schema::ResultSet');
  __PACKAGE__->table("album");
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'C1::Schema::Result::Artist', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package C1::Schema::Result::Artist;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->resultset_class('C1::Schema::ResultSet');
  __PACKAGE__->table("artist");
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(albums => 'C1::Schema::Result::Album', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for('albums');

  package C1::Schema::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  package C1::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Artist => 'C1::Schema::Result::Artist');
  __PACKAGE__->register_class(Album => 'C1::Schema::Result::Album');
}

ok my $schema = C1::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

{
  # invalid create: returned unsaved, carrying errors
  ok my $bad = $schema->resultset('Artist')->create({ name => 'X' }), 'create returns a row';
  ok $bad->invalid, 'row is invalid';
  ok !$bad->in_storage, 'invalid row was NOT inserted';
  ok my ($msg) = $bad->errors->full_messages_for('name'), 'name has an error message';
}

{
  # valid create persists
  ok my $good = $schema->resultset('Artist')->create({ name => 'Nirvana' }), 'valid create';
  ok $good->valid, 'row is valid';
  ok $good->in_storage, 'valid row inserted';

  # update runs validations and refuses invalid changes
  $good->update({ name => 'N' });
  ok $good->invalid, 'update validation failed';
  $good->discard_changes;
  is $good->name, 'Nirvana', 'database value unchanged after invalid update';
}

{
  # nested create: child errors block the whole graph and aggregate upward
  ok my $nested = $schema->resultset('Artist')->create({
    name => 'Pearl Jam',
    albums => [ { title => 'Ten' }, { title => 'x' } ],
  }), 'nested create returns a row';
  ok $nested->invalid, 'parent invalid because a child is invalid';
  ok !$nested->in_storage, 'parent not inserted';
  ok my @msgs = $nested->errors->full_messages_for('albums'), 'albums aggregated an error';
  is $schema->resultset('Album')->count, 0, 'no albums inserted';
}

{
  # valid nested create persists parent and children
  ok my $ok_nested = $schema->resultset('Artist')->create({
    name => 'Soundgarden',
    albums => [ { title => 'Superunknown' } ],
  }), 'valid nested create';
  ok $ok_nested->valid, 'graph valid';
  ok $ok_nested->in_storage, 'parent inserted';
  is $schema->resultset('Album')->count, 1, 'child inserted';
}

{
  # skip_validation escape hatch on the resultset
  ok my $skipped = $schema->resultset('Artist')->skip_validate->create({ name => 'X' }),
    'create with skip_validate';
  ok $skipped->in_storage, 'validation was skipped so the row persisted';
}

done_testing;
```

- [ ] **Step 5: Run it**

Run: `prove -lv t/dbio/component.t`
Expected: PASS. This is the highest-risk test of the whole port (it exercises insert/update overrides, nested params, the resultset cache round-trip, and validator namespace resolution on DBIO for the first time). If it fails: diagnose root cause per Global Constraints. Known-plausible divergence points to check first: (a) component load order — `load_components('Valiant::Result')` must come before anything else on the class; (b) `quote_names` is ON by default in DBIO (a DBIC departure) — irrelevant to these APIs but visible in traces; (c) leftover `DBIx` strings (`grep -rn "DBIx" lib/DBIO/`).

- [ ] **Step 6: Commit**

```bash
git add lib/DBIO/Valiant/Result.pm lib/DBIO/Valiant/ResultSet.pm lib/DBIO/Valiant/Validator t/dbio/component.t
git commit -m "Port DBIO::Valiant Result/ResultSet components and validators

Drops the many_to_many override (DBIO records _m2m_metadata natively)
and the unused generated \${rel}_pks helper.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: HTML FormFields component

**Files:**
- Create: `lib/DBIO/Valiant/Result/HTML/FormFields.pm` (from `lib/DBIx/Class/Valiant/Result/HTML/FormFields.pm`)
- Test: `t/dbio/form-fields.t`

**Interfaces:**
- Produces: `load_components('Valiant::Result::HTML::FormFields')` providing `tags_by_column`, `columns_by_tag`, `read_attribute_for_html`, and the `add_*_rs_for` registries — same surface as the DBIC version.

- [ ] **Step 1: Copy and rename**

```bash
mkdir -p lib/DBIO/Valiant/Result/HTML
cp lib/DBIx/Class/Valiant/Result/HTML/FormFields.pm lib/DBIO/Valiant/Result/HTML/FormFields.pm
```

Apply the Standard Rename (this file contains `use base 'DBIx::Class';` — step 1 of the rename applies).

- [ ] **Step 2: Write the test**

Create `t/dbio/form-fields.t`:

```perl
use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

{
  package FF::Schema::Result::Status;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result::HTML::FormFields', 'Valiant::Result');
  __PACKAGE__->table("status");
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1, tags => ['option_value'] },
    label => { data_type => 'varchar', is_nullable => 0, size => 24, tags => ['option_label'] },
  );
  __PACKAGE__->set_primary_key("id");

  package FF::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Status => 'FF::Schema::Result::Status');
}

is_deeply [FF::Schema::Result::Status->tags_by_column('label')], ['option_label'],
  'tags_by_column reads tag metadata from column info';
is_deeply [FF::Schema::Result::Status->columns_by_tag('option_label')], ['label'],
  'columns_by_tag reverse lookup';

ok my $schema = FF::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;
ok my $status = $schema->resultset('Status')->create({ label => 'active' });
is $status->read_attribute_for_html('label'), 'active', 'read_attribute_for_html reads column value';
is $status->read_attribute_for_html('_add'), 1, '_add pseudo attribute';

done_testing;
```

- [ ] **Step 3: Run it**

Run: `prove -lv t/dbio/form-fields.t`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/DBIO/Valiant/Result/HTML/FormFields.pm t/dbio/form-fields.t
git commit -m "Port DBIO::Valiant::Result::HTML::FormFields

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: TestDBIO bootstrap + ExampleIO schema + basic.t

**Files:**
- Create: `t/lib/TestDBIO.pm` (new — replaces Test::DBIx::Class for the DBIO lane)
- Create: `t/lib/ExampleIO/Schema.pm` (from `t/lib/Example/Schema.pm`)
- Create: `t/lib/ExampleIO/Schema/Result.pm`, `t/lib/ExampleIO/Schema/ResultSet.pm`, `t/lib/ExampleIO/Schema/DefaultRS.pm` (from the `t/lib/Example/Schema/` counterparts)
- Create: `t/lib/ExampleIO/Schema/Result/{Person,Profile,State,CreditCard,Role,PersonRole,Test}.pm` (from `t/lib/Example/Schema/Result/*.pm`)
- Create: `t/lib/ExampleIO/Schema/ResultSet/PersonRole.pm` (from `t/lib/Example/Schema/ResultSet/PersonRole.pm`)
- Create: `t/dbio/basic.t` (from `t/dbic/basic.t`, 915 lines)

**Interfaces:**
- Produces: `use TestDBIO -schema_class => 'ExampleIO::Schema';` exports a `Schema` function returning a connected + deployed in-memory SQLite DBIO schema (mirrors the `Schema` function Test::DBIx::Class exports, which is the only Test::DBIx::Class feature the dbic tests use). Optional `-async => 'immediate'` passes `{ async => 'immediate' }` into connect (used from Task 14 on).

- [ ] **Step 1: Write the bootstrap helper**

Create `t/lib/TestDBIO.pm`:

```perl
package TestDBIO;

use strict;
use warnings;

# Minimal stand-in for the one Test::DBIx::Class feature the dbic test
# suite uses: a 'Schema' function bound to a connected, deployed,
# in-memory SQLite schema.
#
#   use TestDBIO -schema_class => 'ExampleIO::Schema';
#   use TestDBIO -schema_class => 'ExampleIO::Schema', -async => 'immediate';

my $schema;

sub import {
  my ($class, %opts) = @_;
  my $caller = caller;
  my $schema_class = $opts{'-schema_class'}
    or die "TestDBIO requires -schema_class";

  eval "require $schema_class; 1" or die $@;

  my %attrs = (RaiseError => 1);
  $attrs{async} = $opts{'-async'} if $opts{'-async'};

  $schema = $schema_class->connect('dbi:SQLite:dbname=:memory:', '', '', \%attrs);
  $schema->deploy;

  no strict 'refs';
  *{"${caller}::Schema"} = sub { $schema };
}

1;
```

- [ ] **Step 2: Port the ExampleIO schema**

```bash
mkdir -p t/lib/ExampleIO/Schema/Result t/lib/ExampleIO/Schema/ResultSet
cp t/lib/Example/Schema.pm t/lib/ExampleIO/Schema.pm
cp t/lib/Example/Schema/Result.pm t/lib/ExampleIO/Schema/Result.pm
cp t/lib/Example/Schema/ResultSet.pm t/lib/ExampleIO/Schema/ResultSet.pm
cp t/lib/Example/Schema/DefaultRS.pm t/lib/ExampleIO/Schema/DefaultRS.pm
cp t/lib/Example/Schema/Result/Person.pm t/lib/ExampleIO/Schema/Result/Person.pm
cp t/lib/Example/Schema/Result/Profile.pm t/lib/ExampleIO/Schema/Result/Profile.pm
cp t/lib/Example/Schema/Result/State.pm t/lib/ExampleIO/Schema/Result/State.pm
cp t/lib/Example/Schema/Result/CreditCard.pm t/lib/ExampleIO/Schema/Result/CreditCard.pm
cp t/lib/Example/Schema/Result/Role.pm t/lib/ExampleIO/Schema/Result/Role.pm
cp t/lib/Example/Schema/Result/PersonRole.pm t/lib/ExampleIO/Schema/Result/PersonRole.pm
cp t/lib/Example/Schema/Result/Test.pm t/lib/ExampleIO/Schema/Result/Test.pm
cp t/lib/Example/Schema/ResultSet/PersonRole.pm t/lib/ExampleIO/Schema/ResultSet/PersonRole.pm
```

To every copied file apply, in this order:
1. `perl -pi -e 's/Example::Schema/ExampleIO::Schema/g'`
2. The Standard Rename (both steps).

Verify: `grep -rln "DBIx\|Example::Schema" t/lib/ExampleIO/` prints nothing.

(For reference, `ExampleIO/Schema/Result.pm` should end up as: `use base 'DBIO::Base';` + `load_components(qw/Valiant::Result Core InflateColumn::DateTime/)` — both `DBIO::InflateColumn::DateTime` and `DBIO::ResultClass::HashRefInflator` (used by `ResultSet.pm`'s `to_array`) exist in DBIO, verified.)

- [ ] **Step 3: Port basic.t**

```bash
cp t/dbic/basic.t t/dbio/basic.t
```

In `t/dbio/basic.t`, replace the two-line bootstrap:

```perl
use Test::DBIx::Class
  -schema_class => 'Example::Schema';
```

with:

```perl
use TestDBIO
  -schema_class => 'ExampleIO::Schema';
```

and add `use Test::Needs 'DBIO', 'DBIO::SQLite';` immediately after the `use Test::Most;` line. Then rename any remaining schema references: `perl -pi -e 's/Example::Schema/ExampleIO::Schema/g' t/dbio/basic.t`. (`use Test::Lib;` stays — it adds `t/lib` to `@INC`.)

- [ ] **Step 4: Run it**

Run: `prove -lv t/dbio/basic.t`
Expected: PASS (915 lines of assertions — this is the DBIC glue's primary conformance suite running against DBIO). Failures here are the most valuable output of the whole project: root-cause each one. Categorize into (a) port mistakes (fix), (b) DBIO behavioral differences (STOP, document in `dbio-integration-notes.md`, discuss with John), (c) upstream DBIO bugs (document; candidate Codeberg issue/patch).

- [ ] **Step 5: Commit**

```bash
git add t/lib/TestDBIO.pm t/lib/ExampleIO t/dbio/basic.t
git commit -m "Add DBIO test bootstrap, ExampleIO schema, and port basic.t

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: SchemaIO shared bases + Create schema + create.t

**Files:**
- Create: `t/lib/SchemaIO/Result.pm`, `t/lib/SchemaIO/ResultSet.pm`, `t/lib/SchemaIO/DefaultRS.pm` (from `t/lib/Schema/{Result,ResultSet,DefaultRS}.pm`)
- Create: `t/lib/SchemaIO/Create.pm` (from `t/lib/Schema/Create.pm`)
- Create: `t/lib/SchemaIO/Create/Result/Person.pm`, `t/lib/SchemaIO/Create/Result/Profile.pm` (from `t/lib/Schema/Create/Result/*.pm`)
- Create: `t/dbio/create.t` (from `t/dbic/create.t`, 494 lines)

**Interfaces:**
- Consumes: `TestDBIO` (Task 6).
- Produces: `SchemaIO::Create` schema used by Tasks 8-9; `SchemaIO::{Result,ResultSet,DefaultRS}` bases shared with `SchemaIO::Nested` (Task 10).

- [ ] **Step 1: Copy and rename**

```bash
mkdir -p t/lib/SchemaIO/Create/Result
cp t/lib/Schema/Result.pm t/lib/SchemaIO/Result.pm
cp t/lib/Schema/ResultSet.pm t/lib/SchemaIO/ResultSet.pm
cp t/lib/Schema/DefaultRS.pm t/lib/SchemaIO/DefaultRS.pm
cp t/lib/Schema/Create.pm t/lib/SchemaIO/Create.pm
cp t/lib/Schema/Create/Result/Person.pm t/lib/SchemaIO/Create/Result/Person.pm
cp t/lib/Schema/Create/Result/Profile.pm t/lib/SchemaIO/Create/Result/Profile.pm
```

To every copied file apply, in order:
1. `perl -pi -e 's/\bSchema::/SchemaIO::/g'` (renames `Schema::Result`, `Schema::Create`, `Schema::Nested` references, including the `+Schema::DefaultRS` form in `Create.pm`; the leading word-boundary keeps `Example::Schema`-style names — absent in these files — safe)
2. The Standard Rename (both steps).

Note: the `Schema::Create` result classes use `DBIx::Class::Candy` (`use DBIx::Class::Candy -base => 'Schema::Result'`) — the Standard Rename turns this into `use DBIO::Candy -base => 'SchemaIO::Result'`. This is deliberate coverage: it proves the `DBIO::Candy::Exports` integration (the `validates` / `filters` / `accept_nested_for` sugar exported by our component into Candy classes) works.

Verify: `grep -rln "DBIx" t/lib/SchemaIO/` prints nothing, and `grep -rn "package Schema" t/lib/SchemaIO/` prints nothing (all packages now `SchemaIO::...`).

- [ ] **Step 2: Port create.t**

```bash
cp t/dbic/create.t t/dbio/create.t
```

Replace the bootstrap lines:

```perl
use Test::DBIx::Class
  -schema_class => 'Schema::Create';
```

with:

```perl
use TestDBIO
  -schema_class => 'SchemaIO::Create';
```

Add `use Test::Needs 'DBIO', 'DBIO::SQLite';` after `use Test::Most;`. Then: `perl -pi -e 's/\bSchema::Create/SchemaIO::Create/g' t/dbio/create.t`.

- [ ] **Step 3: Run it**

Run: `prove -lv t/dbio/create.t`
Expected: PASS. Same failure triage protocol as Task 6 Step 4.

- [ ] **Step 4: Commit**

```bash
git add t/lib/SchemaIO t/dbio/create.t
git commit -m "Port SchemaIO::Create test schema and create.t to DBIO lane

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: new_result.t

**Files:**
- Create: `t/dbio/new_result.t` (from `t/dbic/new_result.t`, 47 lines)

**Interfaces:**
- Consumes: `SchemaIO::Create` (Task 7), `TestDBIO` (Task 6).

- [ ] **Step 1: Copy and adapt**

```bash
cp t/dbic/new_result.t t/dbio/new_result.t
```

Apply the same three edits as Task 7 Step 2: bootstrap replacement (`use Test::DBIx::Class\n  -schema_class => 'Schema::Create';` → `use TestDBIO\n  -schema_class => 'SchemaIO::Create';`), add `use Test::Needs 'DBIO', 'DBIO::SQLite';`, then `perl -pi -e 's/\bSchema::Create/SchemaIO::Create/g' t/dbio/new_result.t`.

- [ ] **Step 2: Run it**

Run: `prove -lv t/dbio/new_result.t`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add t/dbio/new_result.t
git commit -m "Port new_result.t to DBIO lane

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: update.t

**Files:**
- Create: `t/dbio/update.t` (from `t/dbic/update.t`, 55 lines)

**Interfaces:**
- Consumes: `SchemaIO::Create` (Task 7), `TestDBIO` (Task 6).

- [ ] **Step 1: Copy and adapt**

```bash
cp t/dbic/update.t t/dbio/update.t
```

Apply the same three edits as Task 7 Step 2 (bootstrap → `TestDBIO -schema_class => 'SchemaIO::Create'`, add Test::Needs, `s/\bSchema::Create/SchemaIO::Create/g`).

- [ ] **Step 2: Run it**

Run: `prove -lv t/dbio/update.t`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add t/dbio/update.t
git commit -m "Port update.t to DBIO lane

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: SchemaIO::Nested + nested.t

**Files:**
- Create: `t/lib/SchemaIO/Nested.pm` (from `t/lib/Schema/Nested.pm`)
- Create: `t/lib/SchemaIO/Nested/Result/*.pm` — all 19 files: `Child, Meeting, Meeting/Attendee, Might, Might2, Might3, One, One2, One3, OneOne, OneOne2, Parent, Person, PersonRole, Role, State, XBottom, XChild, XMiddle, XTop` (from `t/lib/Schema/Nested/Result/`)
- Create: `t/dbio/nested.t` (from `t/dbic/nested.t`, 859 lines)

**Interfaces:**
- Consumes: `SchemaIO::{Result,ResultSet,DefaultRS}` bases (Task 7), `TestDBIO` (Task 6).
- Produces: `SchemaIO::Nested` used by Tasks 11-13.

- [ ] **Step 1: Copy and rename**

```bash
mkdir -p t/lib/SchemaIO/Nested/Result/Meeting
cp t/lib/Schema/Nested.pm t/lib/SchemaIO/Nested.pm
cp t/lib/Schema/Nested/Result/*.pm t/lib/SchemaIO/Nested/Result/
cp t/lib/Schema/Nested/Result/Meeting/Attendee.pm t/lib/SchemaIO/Nested/Result/Meeting/Attendee.pm
```

To every copied file apply, in order (same rules as Task 7):
1. `perl -pi -e 's/\bSchema::/SchemaIO::/g'`
2. The Standard Rename (both steps).

Verify: `grep -rln "DBIx" t/lib/SchemaIO/Nested* t/lib/SchemaIO/Nested/` prints nothing; `grep -rn "package Schema" t/lib/SchemaIO/` prints nothing.

- [ ] **Step 2: Port nested.t**

```bash
cp t/dbic/nested.t t/dbio/nested.t
```

Bootstrap replacement (`-schema_class => 'Schema::Nested'` → `use TestDBIO -schema_class => 'SchemaIO::Nested';`), add `use Test::Needs 'DBIO', 'DBIO::SQLite';`, then `perl -pi -e 's/\bSchema::Nested/SchemaIO::Nested/g' t/dbio/nested.t`.

- [ ] **Step 3: Run it**

Run: `prove -lv t/dbio/nested.t`
Expected: PASS. This is the deepest exercise of the nested create/update/delete machinery (859 lines) — apply the Task 6 Step 4 triage protocol to any failure.

- [ ] **Step 4: Commit**

```bash
git add t/lib/SchemaIO/Nested.pm t/lib/SchemaIO/Nested t/dbio/nested.t
git commit -m "Port SchemaIO::Nested schema and nested.t to DBIO lane

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: nested2.t + nested3.t

**Files:**
- Create: `t/dbio/nested2.t` (from `t/dbic/nested2.t`, 122 lines)
- Create: `t/dbio/nested3.t` (from `t/dbic/nested3.t`, 125 lines)

**Interfaces:**
- Consumes: `SchemaIO::Nested` (Task 10), `TestDBIO` (Task 6).

- [ ] **Step 1: Copy and adapt both files**

```bash
cp t/dbic/nested2.t t/dbio/nested2.t
cp t/dbic/nested3.t t/dbio/nested3.t
```

To each: bootstrap replacement (`use Test::DBIx::Class\n  -schema_class => 'Schema::Nested';` → `use TestDBIO\n  -schema_class => 'SchemaIO::Nested';`), add `use Test::Needs 'DBIO', 'DBIO::SQLite';` after `use Test::Most;`, then `perl -pi -e 's/\bSchema::Nested/SchemaIO::Nested/g' t/dbio/nested2.t t/dbio/nested3.t`.

- [ ] **Step 2: Run them**

Run: `prove -lv t/dbio/nested2.t t/dbio/nested3.t`
Expected: PASS ×2.

- [ ] **Step 3: Commit**

```bash
git add t/dbio/nested2.t t/dbio/nested3.t
git commit -m "Port nested2.t and nested3.t to DBIO lane

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 12: resultsets.t

**Files:**
- Create: `t/dbio/resultsets.t` (from `t/dbic/resultsets.t`, 161 lines)

**Interfaces:**
- Consumes: `SchemaIO::Nested` (Task 10), `TestDBIO` (Task 6). Exercises `set_recursively` (and therefore the `insert_or_update` alias verified in Task 4 Step 3).

- [ ] **Step 1: Copy and adapt**

```bash
cp t/dbic/resultsets.t t/dbio/resultsets.t
```

Same three edits as Task 11 Step 1 (bootstrap → `SchemaIO::Nested`, Test::Needs, rename sweep on `t/dbio/resultsets.t`).

- [ ] **Step 2: Run it**

Run: `prove -lv t/dbio/resultsets.t`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add t/dbio/resultsets.t
git commit -m "Port resultsets.t to DBIO lane

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 13: m2m.t — the native-m2m proof

**Files:**
- Create: `t/dbio/m2m.t` (from `t/dbic/m2m.t`, 381 lines)

**Interfaces:**
- Consumes: `SchemaIO::Nested` (Task 10), `TestDBIO` (Task 6). This test is the proof that dropping the `many_to_many` override (Task 4 Step 2) was safe: every m2m path here now runs on DBIO's native `_m2m_metadata`.

- [ ] **Step 1: Copy and adapt**

```bash
cp t/dbic/m2m.t t/dbio/m2m.t
```

Same three edits as Task 11 Step 1 (bootstrap → `SchemaIO::Nested`, Test::Needs, rename sweep on `t/dbio/m2m.t`). Additionally scan for any use of a generated `*_pks` method (`grep -n "_pks" t/dbio/m2m.t`) — none is expected (verified unused in the whole dist); if one appears, STOP and revisit the Task 4 decision with John.

- [ ] **Step 2: Run it**

Run: `prove -lv t/dbio/m2m.t`
Expected: PASS. If m2m metadata is missing at runtime, the first place to look: DBIO's `many_to_many` declares `_m2m_metadata` only `unless $class->can('_m2m_metadata')` — the component's `mk_classdata` (kept in Task 4 Step 2) must be loaded BEFORE the schema class declares its `many_to_many` relationships (i.e. `load_components` order in the result class).

- [ ] **Step 3: Commit**

```bash
git add t/dbio/m2m.t
git commit -m "Port m2m.t to DBIO lane, proving native _m2m_metadata suffices

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Note: `t/dbic/todo_tests.t` is a stub (`ok 1` + design notes in `__END__`) — deliberately not ported.

---

### Task 14: insert_async validation gating

**Files:**
- Modify: `lib/DBIO/Valiant/Result.pm` (add `insert_async` after `sub insert`, plus POD)
- Test: `t/dbio/async-immediate.t` (immediate mode — pins the already-working sync-funnel contract)
- Test: `t/dbio/async-backend.t` (mock async backend over REAL SQLite storage — the TDD failing test for the gating logic)

**Interfaces:**
- Consumes: everything from Task 4; DBIO internals `$storage->_async_storage` (returns the live embedded backend or undef) and `$storage->future_class` (public, default `DBIO::Future::Immediate`); `DBIO::Storage::DBI->register_async_mode(name => class)` and `DBIO::Storage::Async` as mock base (upstream's own test pattern, `~/Desktop/dbio/t/resultset/async_backend.t`).
- Produces: `DBIO::Valiant::Result::insert_async` — on a live async backend, an invalid row resolves the Future with the errored, un-inserted row instead of writing to the DB. All other paths (sync croak, immediate mode, rows with relationship data) delegate unchanged to `next::method`.

Background (from `dbio-integration-notes.md` Part 2): upstream `DBIO::Row::insert_async` already funnels rows with `_relationship_data`/`_inflated_column`, and all `immediate`-mode inserts, through the C3-composed synchronous `insert` — where our validation already runs. Only the live-backend, no-relationship-data fast path bypasses it. That is the one hole this task closes.

- [ ] **Step 1: Write the immediate-mode contract test (expected to pass immediately)**

Create `t/dbio/async-immediate.t`:

```perl
use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';
use Test::Lib;
use TestDBIO
  -schema_class => 'SchemaIO::Create',
  -async => 'immediate';

# In 'immediate' mode every *_async runs the composed synchronous method
# and wraps the result -- so Valiant validation gating applies unchanged.

{
  # all NOT NULL columns supplied (so only validation, not a DB constraint,
  # can reject this) but username fails length[3,24] and password fails
  # length[8,24] per SchemaIO::Create::Result::Person's rules
  ok my $f = Schema->resultset('Person')->create_async({
    username => 'x', first_name => 'john', last_name => 'napiorkowski', password => 'short',
  }), 'create_async returns something';
  ok $f->is_ready, 'immediate mode future is already resolved';
  ok my $person = $f->get, 'future resolves to the row';
  ok $person->invalid, 'row is invalid';
  ok !$person->in_storage, 'invalid row was not inserted';
}

{
  # password confirmation is required on the create context (injected
  # password_confirmation attribute) -- payload mirrors t/dbic/create.t
  ok my $f = Schema->resultset('Person')->create_async({
    username => 'jjn', first_name => 'john', last_name => 'napiorkowski',
    password => 'hellohello', password_confirmation => 'hellohello',
  }), 'valid create_async';
  ok my $person = $f->get, 'future resolves';
  ok $person->valid, 'row is valid';
  ok $person->in_storage, 'valid row inserted';
}

done_testing;
```

(Payloads are verified against `Schema::Create::Result::Person`'s validations: username presence/length[3,24]/format/unique, first_name, last_name, password length[8,24] + confirmation on the create context.)

- [ ] **Step 2: Run it**

Run: `prove -lv t/dbio/async-immediate.t`
Expected: PASS with NO new lib/ code — this pins the upstream sync-funnel behavior. If it fails, the failure is a finding about `immediate` mode (triage per Global Constraints), not something to fix by writing the override yet.

- [ ] **Step 3: Commit the contract test**

```bash
git add t/dbio/async-immediate.t
git commit -m "Pin immediate-mode async validation contract for DBIO lane

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Write the failing backend test**

Create `t/dbio/async-backend.t`. The mock here adapts upstream's own harness (`~/Desktop/dbio/t/resultset/async_backend.t`): it is an async *routing seam* that delegates every operation to the REAL, connected SQLite sync storage — real SQL, real database, no fake data. (The genuine end-to-end async lane is Task 15's PostgreSQL test.)

```perl
use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';
use Test::Lib;

use DBIO::Future::Immediate;
use DBIO::Storage::Async;
use DBIO::Storage::DBI;

# A mock async backend that routes *_async calls to the REAL SQLite sync
# storage of the connected schema (adapted from DBIO's own
# t/resultset/async_backend.t). It exists to drive the live-backend code
# path in Row::insert_async without an event loop.
{
  package Valiant::Test::MockBackend;

  use base 'DBIO::Storage::Async';

  our $SYNC; # the real connected sync storage, set after connect below

  sub new { my ($class, $schema) = @_; return bless +{ schema => $schema }, $class }
  sub future_class { 'DBIO::Future::Immediate' }
  sub connect_info { my $self = shift; $self->{connect_info} = shift if @_; return $self->{connect_info} }
  sub disconnect { 1 }

  sub select_async {
    my ($self, @args) = @_;
    my @rows = $SYNC->select(@args)->all;
    return DBIO::Future::Immediate->done(@rows);
  }

  sub select_single_async {
    my ($self, @args) = @_;
    my @row = $SYNC->select_single(@args);
    return DBIO::Future::Immediate->done( @row ? [ @row ] : undef );
  }

  sub insert_async {
    my ($self, @args) = @_;
    my $cols = $SYNC->insert(@args);
    return DBIO::Future::Immediate->done($cols);
  }
}

DBIO::Storage::DBI->register_async_mode( valiant_mock => 'Valiant::Test::MockBackend' );

require SchemaIO::Create;
ok my $schema = SchemaIO::Create->connect(
  'dbi:SQLite:dbname=:memory:', '', '',
  { RaiseError => 1, async => 'valiant_mock' },
), 'connected with mock async backend';
$schema->deploy;
$Valiant::Test::MockBackend::SYNC = $schema->storage;

ok $schema->storage->_async_storage, 'live backend resolved';

{
  # THE gating test: a simple (no nested data) INVALID create_async must
  # NOT reach the backend insert; it resolves with the errored row.
  # All NOT NULL columns are supplied so the DB itself would accept the
  # row -- only Valiant validation can (and must) stop it.
  ok my $f = $schema->resultset('Person')->create_async({
    username => 'x', first_name => 'john', last_name => 'napiorkowski', password => 'short',
  }), 'create_async on invalid data returns a future';
  ok my $person = $f->get, 'future resolves to the row';
  ok $person->invalid, 'row carries validation errors';
  ok !$person->in_storage, 'row was NOT inserted';
  is $schema->resultset('Person')->count, 0, 'database is empty';
}

{
  # valid rows pass through to the backend insert
  ok my $f = $schema->resultset('Person')->create_async({
    username => 'jjn', first_name => 'john', last_name => 'napiorkowski',
    password => 'hellohello', password_confirmation => 'hellohello',
  }), 'valid create_async';
  ok my $person = $f->get, 'future resolves';
  ok $person->in_storage, 'valid row inserted through the backend';
  is $schema->resultset('Person')->count, 1, 'row is in the database';
}

done_testing;
```

(Payloads verified against `Schema::Create::Result::Person` — see Step 1.) If `register_async_mode`/`_async_storage` shapes differ from this sketch at runtime, mirror upstream's exact test file — it is the authoritative pattern.

- [ ] **Step 5: Run it — must FAIL**

Run: `prove -lv t/dbio/async-backend.t`
Expected: FAIL at `'row was NOT inserted'` / `'database is empty'` — the live-backend fast path currently bypasses validation, so the invalid row IS inserted. This failure is the proof the override is needed. (If it passes without the override, STOP — the analysis in the notes is wrong somewhere; re-read `DBIO::Row::insert_async` before proceeding.)

- [ ] **Step 6: Implement the override**

In `lib/DBIO/Valiant/Result.pm`, add directly AFTER the closing brace of `sub insert` (keeping its style):

```perl
sub insert_async {
  my ($self, @args) = @_;

  # Everything except the live-backend fast path already funnels through the
  # composed synchronous ->insert upstream (sync connections croak, 'immediate'
  # mode and rows carrying related data run ->insert), where validation runs.
  # Only a simple row on a live async backend would bypass it, so that's the
  # only case we gate here.
  my $storage = $self->result_source->storage;
  return $self->next::method(@args) unless $storage->_async_storage;
  return $self->next::method(@args)
    if %{ $self->{_relationship_data} ||+{} }
    or %{ $self->{_inflated_column} ||+{} };
  return $self->next::method(@args)
    if $self->{__valiant_donot_insert} || $self->{__valiant_add} || !$self->auto_validation;

  my %args = %{ $self->{__VALIANT_CREATE_ARGS} ||+{} };
  my $context = $args{context}||[];
  my @context = (ref($context)||'') eq 'ARRAY' ? @$context : ($context);
  push @context, 'create' unless grep { $_ eq 'create' } @context;
  $args{context} = \@context;

  debug 2, "Checking if row for insert_async is marked for deletion @{[$self]}";
  return $storage->future_class->done($self) if $self->is_marked_for_deletion;

  debug 2, "About to run validations for @{[$self]} on insert_async";
  $self->validate(%args);
  if($self->errors->size) {
    debug 2, "Skipping insert_async for @{[$self]} because its invalid";
    return $storage->future_class->done($self);
  }

  return $self->next::method(@args);
}
```

And add POD for it in the `=head1 METHODS` section of the same file, in the same commit:

```pod
=head2 insert_async

Async-aware version of the validation wrapper around C<insert>.  On a live
async backend a simple row (one with no pending related data) is validated
before the non-blocking insert is issued; if validation fails the returned
Future resolves immediately with the invalid row (not inserted), exactly
mirroring the synchronous C<insert> contract.  All other cases (synchronous
connections, C<immediate> mode, rows with pending related data) delegate to
the upstream method, which routes them through the composed synchronous
C<insert> where validation already runs.

Note that C<validate> itself runs synchronously; validators that query the
database (for example C<unique>) will block the event loop for the duration
of that query.
```

- [ ] **Step 7: Run both async tests — must PASS**

Run: `prove -lv t/dbio/async-backend.t t/dbio/async-immediate.t`
Expected: PASS ×2.

- [ ] **Step 8: Regression-run the whole DBIO lane**

Run: `prove -lr t/dbio`
Expected: all files PASS (the override must not disturb any sync path).

- [ ] **Step 9: Commit**

```bash
git add lib/DBIO/Valiant/Result.pm t/dbio/async-backend.t
git commit -m "Gate live-backend insert_async on Valiant validation

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 15: Env-guarded PostgreSQL real-async lane

**Files:**
- Create: `t/dbio/async-pg.t`

**Interfaces:**
- Consumes: `SchemaIO::Create` (Task 7), the `insert_async` override (Task 14). Requires at runtime (all guarded, none added to cpanfile): `DBIO::PostgreSQL`, an async mode dist (`dbio-async` for `future_io`), a live PostgreSQL in `$ENV{VALIANT_TEST_DBIO_PG_DSN}` (+ `_USER`, `_PASS`).

- [ ] **Step 1: Write the guarded test**

Create `t/dbio/async-pg.t`:

```perl
use Test::Most;

BEGIN {
  plan skip_all => 'set VALIANT_TEST_DBIO_PG_DSN (+_USER, _PASS) for the real-async PostgreSQL lane'
    unless $ENV{VALIANT_TEST_DBIO_PG_DSN};
}

use Test::Needs 'DBIO', 'DBIO::PostgreSQL', 'DBIO::Async::Storage';
use Test::Lib;

require SchemaIO::Create;

ok my $schema = SchemaIO::Create->connect(
  $ENV{VALIANT_TEST_DBIO_PG_DSN},
  $ENV{VALIANT_TEST_DBIO_PG_USER}||'',
  $ENV{VALIANT_TEST_DBIO_PG_PASS}||'',
  { RaiseError => 1, async => 'future_io' },
), 'connected to PostgreSQL with future_io async mode';

$schema->deploy;

{
  # invalid simple create_async: validation gates the non-blocking insert
  ok my $f = $schema->resultset('Person')->create_async({
    username => 'x', first_name => 'john', last_name => 'napiorkowski', password => 'short',
  });
  ok my $person = $f->get, 'future resolved';
  ok $person->invalid, 'row invalid';
  ok !$person->in_storage, 'row not inserted';
  is $schema->resultset('Person')->count, 0, 'table empty';
}

{
  # valid simple create_async really goes through the async backend
  ok my $f = $schema->resultset('Person')->create_async({
    username => 'jjn', first_name => 'john', last_name => 'napiorkowski',
    password => 'hellohello', password_confirmation => 'hellohello',
  });
  ok my $person = $f->get, 'future resolved';
  ok $person->valid, 'row valid';
  ok $person->in_storage, 'row inserted';
  is $schema->resultset('Person')->count, 1, 'row in table';
}

# leave the scratch database clean for reruns
$schema->resultset('Person')->delete;

done_testing;
```

(Payloads verified against `Schema::Create::Result::Person` — see Task 14 Step 1.) If `deploy` against an existing PG scratch DB errors on pre-existing tables, that is environment-specific — document the required empty-database precondition in a comment at the top of the test rather than adding drop/create logic.

- [ ] **Step 2: Run it (both modes)**

Run: `prove -lv t/dbio/async-pg.t`
Expected without env vars: `skipped: set VALIANT_TEST_DBIO_PG_DSN ...` — this is the normal CI/local result.
If a PG instance is available, export the three env vars and run again; expected PASS. If no PG is available in this session, the skip result is the acceptance criterion — note in the commit message that live-PG execution is pending.

- [ ] **Step 3: Commit**

```bash
git add t/dbio/async-pg.t
git commit -m "Add env-guarded PostgreSQL real-async test lane

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 16: Main documentation, Changes, full-suite regression

**Files:**
- Create: `lib/DBIO/Valiant.pm` (from `lib/DBIx/Class/Valiant.pm`, 688 lines — POD-only module)
- Modify: `Changes` (new entry under the current dev version)
- Modify: `dbio-integration-notes.md` (status update)

**Interfaces:**
- Consumes: everything. This is the release-readiness gate.

- [ ] **Step 1: Port the main doc**

```bash
cp lib/DBIx/Class/Valiant.pm lib/DBIO/Valiant.pm
```

Apply the Standard Rename. Then hand-edit the prose for the genuine deltas (read the whole file after renaming — it is documentation, so mechanical renames are not enough):
1. In the section describing `many_to_many` (`=head2 Many to Many` under WARNINGS & GOTCHAs): replace the DBIC-era caveat text with a short note that DBIO records m2m metadata natively and DBIO::Valiant uses it directly.
2. Add a new `=head1 ASYNC` section before `=head1 SEE ALSO`:

```pod
=head1 ASYNC

DBIO connections opened with an C<< { async => ... } >> mode work with
DBIO::Valiant.  C<create_async> validates exactly like C<create>: the returned
Future resolves with the result object, and if validation failed the row is
not inserted and carries its C<errors> collection.  Rows with nested related
data are processed by DBIO through the composed synchronous C<insert> (see
L<DBIO::Row/insert_async>), so all nested validation behavior described in
this document applies unchanged.

Validation itself always runs synchronously; validators which query the
database (such as C<unique>) will block the event loop while they run.

See C<t/dbio/async-pg.t> in this distribution for a runnable example against
a real non-blocking PostgreSQL backend.
=cut
```

3. Verify no stale claims: `grep -n "DBIx\|SQL::Translator" lib/DBIO/Valiant.pm` should print nothing.

- [ ] **Step 2: Add the Changes entry**

At the top of `Changes`, under a new dev version heading matching the current `dist.ini` version bumped by one (dist.ini says `version = 0.002019`, so use `0.002020`):

```
0.002020 {{TBD}}
          - New: DBIO::Valiant - the full DBIx::Class::Valiant feature set
          ported to DBIO (https://codeberg.org/dbio/dbio), the asynchronous
          fork of DBIx::Class.  Includes validation gating for the async
          create_async / insert_async paths.  See DBIO::Valiant.
```

(Leave the date as `{{TBD}}` — John sets release dates.)

- [ ] **Step 3: Full-suite regression**

Run: `prove -lr t`
Expected: the ENTIRE suite passes — the DBIC lane (`t/dbic`), the new DBIO lane (`t/dbio`, with async-pg skipping), and every other test directory, proving the port touched nothing outside its own namespace. Any failure in a pre-existing test is a hard stop: bisect against `git stash` to find which commit of this plan caused it.

- [ ] **Step 4: Update the scope notes**

In `dbio-integration-notes.md`, change the `Status:` line at the top to:

```
Status: v1 port implemented (see docs/superpowers/plans/2026-07-07-dbio-valiant-port.md);
upstream follow-ups pending (bless _relationship_data/get_cache contract; row-level
update_async/delete_async when upstream adds them).
```

- [ ] **Step 5: Commit**

```bash
git add lib/DBIO/Valiant.pm Changes dbio-integration-notes.md
git commit -m "Add DBIO::Valiant main documentation and Changes entry

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 17: Coverage deepening

**Files:**
- Create: `t/dbio/nested-options.t`, `t/dbio/pseudo-params.t`, `t/dbio/column-info.t`, `t/dbio/contexts.t` (exact split may vary; one file per concern below)
- Consume + delete when done: `t/dbio/COVERAGE-GAPS.md` (gap notes accumulated during Tasks 6-13)

**Interfaces:**
- Consumes: all schemas and components from earlier tasks.

The DBIC lane's known-thin spots, enumerated from the source read (`dbio-integration-notes.md` Part 1) — each bullet becomes a test block with both a positive and a negative case, using `SchemaIO::Create` or `SchemaIO::Nested` (or a small inline schema where those don't fit). Cover, at minimum:

1. `accept_nested_for` options, each in isolation: `reject_if` (coderef skips matching nested rows), `limit` (scalar AND coderef forms; exceeding throws `DBIO::Valiant::Util::Exception::TooManyRows`), `update_only => 1` (existing related row updated even without PK), `find_with_uniques => 1` (found via unique key; not-found sets a `related_not_found` error) and `find_with_uniques => 'allow_create'` (not-found creates instead), `allow_destroy` (both constant and coderef; `_delete` without it is a no-op).
2. Pseudo-params on `set_from_params_recursively`: `_delete` (incl. the checkbox array form where only the last value counts), `_add`, `_nop`, `_restore`, `_action => 'delete'` / `'nop'`; deletion pruning of children (`is_pruned` / `is_removed`).
3. `ResultSet->set_recursively` with `rollback_on_invalid => 1` (invalid graph rolls back rows already written) and without.
4. Column-definition metadata: `validates => [...]` and `filters => [...]` keys inside `add_columns` info hashes (the `register_column` path — note `ExampleIO::Schema::Result::Person` already uses this for `password`; add the `filters` case).
5. Validation contexts end-to-end: automatic `create`/`update` contexts, user `__context` on `create`, `update`, and `new_result`, context-scoped validations firing only in their context.
6. `is_unique` / `unique => 1`: rejects a duplicate on create; accepts an update that does not change the unique column (the in-storage short-circuit); rejects an update that changes it to a taken value.
7. `build_related` / `build_related_if_empty`: builds into the cache without inserting; `if_empty` is a no-op when the cache is populated; the m2m form.
8. `Validator::Result` on an optional (`might_have`, LEFT join) relation: undef related is NOT an error; undef on a required single relation IS.
9. `SetSize` boundaries: exactly `min`, one below, exactly `max`, one above, and `skip_if_empty`.
10. FormFields registries end-to-end on a deployed schema: `add_select_options_rs_for` + `select_options_for` (label/value method resolution via `option_label`/`option_value` tags), `add_checkbox_rs_for` + `checkboxes_for`, `add_radio_buttons_for` + `radio_buttons_for`, `add_form_field_for` + `read_form_field_for`, and `read_attribute_for_html` fallback order (registered field > column > method > single rel > `Valiant::BadAttribute`).
11. Whatever else `t/dbio/COVERAGE-GAPS.md` accumulated.

Work test-first per concern: write the test block, run it, fix only genuine port bugs it exposes (a failure that also reproduces on the DBIC side is a pre-existing upstream Valiant bug — record it in `dbio-integration-notes.md` and STOP for discussion rather than changing shared `lib/Valiant` code under this plan). Commit per test file:

```bash
git add t/dbio/<file>.t
git commit -m "Deepen DBIO lane coverage: <concern>

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Finish by deleting `t/dbio/COVERAGE-GAPS.md` (its content now lives as tests) and running `prove -lr t/dbio` — all green.

---

## Post-plan follow-ups (explicitly OUT of this plan's scope)

- File the upstream DBIO proposal to bless `_relationship_data` / resultset-cache / `_storage_ident_condition` / `_async_storage` as public contract (ADR-0023-style). Owner: John + Bot, after v1 lands.
- Runtime `requires 'DBIO'` in cpanfile (vs test-only): decide at release time — DBIC precedent in this dist is a hard runtime requires; DBIO test-only keeps installs light. John's call.
- Row-level `update_async`/`delete_async` overrides: blocked on upstream adding those methods.
- Async validator API (validators returning Futures): explicitly deferred; revisit only with a concrete use case.
