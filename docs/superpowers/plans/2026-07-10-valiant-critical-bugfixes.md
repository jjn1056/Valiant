# Valiant — Fix 7 Critical Bugs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Fix the 7 critical, live-verified bugs in core `Valiant` (documented in `CODE-REVIEW.md`), each test-first, with the doc/locale fixes each requires.

**Architecture:** One branch (`fix-critical-validation-bugs`), one TDD commit per bug (failing test → fix → pass), then a full-suite gate and a single PR for review. Every fix is small and localized; the value is the accompanying test that closes the zero-coverage gap that let each bug ship.

**Tech Stack:** Perl (perlbrew `perl-5.40.0@default`), Moo, Test::Most/Test::Lib, i18n via Data::Localize.

## Global Constraints

- Run Perl under perlbrew: `bash -c 'source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && <cmd>'`.
- Single-file test: `prove -l t/<file>.t` (add `-v` for verbose). Full suite: `prove -lr t`.
- **True TDD:** write the test FIRST, run it, and CONFIRM IT FAILS before applying the fix. A test that passes before the fix is not testing the bug.
- **Perl 5.20 compatibility:** no signatures, no postfix deref, no `say`. Match surrounding style.
- **Pristine test output:** the suite must end with zero warnings; two of these bugs (#2, #6) currently emit warnings — the fixes must remove them, not hide them.
- Never `git add -A`; stage only the named paths. End commit messages with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- These are core changes → they land on a branch and go up as a PR for John to merge; do not push to `main`.
- Two fixes touch more than the obvious spot — do not split them: **Bug #2** must land the bounds fix AND the locale-key fix in one commit (otherwise the `id=>0` case dies instead of failing cleanly). **Bug #3** must edit the existing `t/strict.t` in the same commit as the fix (that test currently passes *because of* the bug).

---

### Task 0: Branch

- [ ] **Step 1:** From an up-to-date `main`:
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant checkout main
git -C /Users/jnapiorkowski/Desktop/Valiant pull --ff-only
git -C /Users/jnapiorkowski/Desktop/Valiant checkout -b fix-critical-validation-bugs
```

---

### Task 1: `errors->added`/`of_kind` broken for i18n-tag errors

**Files:** Modify `lib/Valiant/Error.pm`; Test `t/errors.t`.

- [ ] **Step 1 — failing test.** In `t/errors.t`, add `use Valiant::I18N;` just after `use Test::Most;` at the top. Then find the existing lines:
```perl
ok $user2->errors->of_kind('test01', "Is Invalid");
ok ! $user2->errors->of_kind('test0x', "Is Invalid");
```
and add immediately after them:
```perl
ok $user2->errors->of_kind('test01', _t('invalid')),
  'of_kind matches a tag-typed error while ignoring its stored options';
ok $user2->errors->added('test01', _t('invalid')),
  'added matches a tag-typed error while ignoring its stored options';
```

- [ ] **Step 2 — confirm fail.** `prove -l t/errors.t` → the two new assertions FAIL (return false).

- [ ] **Step 3 — fix.** In `lib/Valiant/Error.pm`, in `sub strict_match`, add one line after the `match` guard:
```perl
sub strict_match {
  my ($self, $attribute, $type, $options) = @_;
  return 0 unless $self->match($attribute, $type);
  return 1 unless defined $options;

  # This is different from match because ALL the keys/values in options need to match
  # exactly.  Its possible my approach here is suspect around object comparisons.
  my %options = %{$self->options};
  delete @options{@CALLBACKS_OPTIONS, @MESSAGE_OPTIONS};

  return FreezeThaw::cmpStr(\%options, $options) == 0 ? 1:0;
}
```

- [ ] **Step 4 — confirm pass.** `prove -l t/errors.t` → PASS.

- [ ] **Step 5 — commit.**
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add lib/Valiant/Error.pm t/errors.t
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Fix errors->added/of_kind for i18n-tag errors\n\nstrict_match compared options against undef via FreezeThaw, which never\nmatched, so added/of_kind returned false for every tag-typed error.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 2: `numericality => 'pg_serial'`/`'pg_bigserial'` (bounds + locale)

**Files:** Modify `lib/Valiant/Validator/Numericality.pm` and `lib/Valiant/Validator/locale/errors.pl`; Test `t/validator/numericality.t`.

- [ ] **Step 1 — failing test.** In `t/validator/numericality.t`, before `done_testing;`, add:
```perl
{
  package Local::Test::Numericality::PgSerial;

  use Moo;
  use Valiant::Validations;

  has id => (is=>'ro');

  validates id => (numericality => 'pg_serial');
}

{
  ok my $object = Local::Test::Numericality::PgSerial->new(id=>0);
  ok $object->validate->invalid, 'serial ids start at 1, so 0 is out of range';
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    { id => [ "Id is not in acceptable value range" ] };
}

{
  ok my $object = Local::Test::Numericality::PgSerial->new(id=>5);
  ok $object->validate->valid, 'a real pg_serial value like 5 must validate cleanly';
}
```

- [ ] **Step 2 — confirm fail.** `prove -l t/validator/numericality.t` → the `id=>0` block fails (0 wrongly valid) and `id=>5` block fails (5 wrongly invalid). (Both sub-fixes are needed for the `is_deeply` to resolve its message.)

- [ ] **Step 3 — fix (both edits, one commit).** In `lib/Valiant/Validator/Numericality.pm` replace the two blocks:
```perl
    if($integer eq 'pg_serial') {
      $args->{greater_than_or_equal_to} = 1;
      $args->{less_than_or_equal_to} = 2147483647;
      $args->{message} = _t("pg_serial_err") unless defined $args->{message};
    }
    if($integer eq 'pg_bigserial') {
      $args->{greater_than_or_equal_to} = 1;
      $args->{less_than_or_equal_to} = 9223372036854775807;
      $args->{message} = _t("pg_bigserial_err") unless defined $args->{message};
    }
```
And in `lib/Valiant/Validator/locale/errors.pl` rename the two keys to match the `_err` tags the validator references:
```perl
        pg_serial_err => 'is not in acceptable value range',
        pg_bigserial_err => 'is not in acceptable value range',
```

- [ ] **Step 4 — confirm pass.** `prove -l t/validator/numericality.t` → PASS (no die on the render path).

- [ ] **Step 5 — commit.**
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add lib/Valiant/Validator/Numericality.pm lib/Valiant/Validator/locale/errors.pl t/validator/numericality.t
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Fix numericality pg_serial/pg_bigserial bounds and locale keys\n\npg_serial accepted only 0 (bounds were >=0 AND <=0); real serials are\n1..2147483647. And the pg_serial_err/pg_bigserial_err message tags had no\nmatching locale key (was pg_serial/pg_bigserial), so rendering the error crashed.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 3: `strict => 'Some::Class'` never routes

**Files:** Modify `lib/Valiant/Errors.pm`; Modify `t/strict.t` (an existing test that passes only because of the bug).

- [ ] **Step 1 — correct the existing test to assert real behavior.** In `t/strict.t`, add a tiny exception class near the top (after the existing `use`s):
```perl
{
  package Local::Test::Strict::TooYoung;
  sub throw { my ($class, $message) = @_; die "Too Young: $message" }
}
```
Change the validator option `strict => "Too Young",` to:
```perl
    strict => "Local::Test::Strict::TooYoung",
```
and change that case's assertion block to:
```perl
{
  ok my $object = Local::Test::Strict->new(age=>11);
  ok !eval { $object->validate };
  ok $@ =~m/^Too Young: Age must be greater than or equal to 18/;
}
```

- [ ] **Step 2 — confirm fail.** `prove -l t/strict.t` → the changed block FAILS: today the buggy branch treats the class name as a literal message, so `$@` is `"Local::Test::Strict::TooYoung at .../Errors.pm line 253..."`, which doesn't match.

- [ ] **Step 3 — fix.** In `lib/Valiant/Errors.pm`, delete the stray scalar-ref line so the class-name path is reached:
```perl
  if(my $exception = $options->{strict}) {
    my $message = $error->full_message;
    throw_exception('Strict' => (msg=>$message)) if $exception =~m/^\d+$/ && $exception == 1;
    $exception->($self->object, $message) if( (ref($exception)||'') eq 'CODE');
    $exception->throw($message); # If not 1 then assume its a package name or exception object.
  }
```
(Removed line: `throw_exception('Strict' => (msg=>$exception)) if( (ref(\$exception)||'') eq 'SCALAR');`)

- [ ] **Step 4 — confirm pass.** `prove -l t/strict.t` → PASS (the `strict=>1` and coderef cases still pass; the class-name case now really invokes `->throw`).

- [ ] **Step 5 — commit.**
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add lib/Valiant/Errors.pm t/strict.t
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Fix strict => class-name routing\n\nref(\\\$exception) is SCALAR for any plain string, so a strict class name was\nintercepted as a literal message and never reached ->throw. Removed that branch;\nthe existing t/strict.t case was passing only because of the bug and is corrected.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 4: `OnlyOf` counts `''`/whitespace as filled

**Files:** Modify `lib/Valiant/Validator/OnlyOf.pm`; Test `t/validator/only_of.t`.

- [ ] **Step 1 — failing test.** In `t/validator/only_of.t`, before `done_testing;`, add (adjust the attribute names `opt1`/`opt2` and validator to match the file's existing `Local::Test::OnlyOf` package if they differ — read the file first):
```perl
{
  # A sibling field holding '' (the normal HTML-form case for an unfilled
  # optional field) must NOT count as filled.
  ok my $object = Local::Test::OnlyOf->new(opt1=>'aaa', opt2=>'');
  ok $object->validate->valid, 'an empty-string sibling does not count against max_allowed';
}
```

- [ ] **Step 2 — confirm fail.** `prove -l t/validator/only_of.t` → new block FAILS (`''` wrongly counted, so 2 > max_allowed=1).

- [ ] **Step 3 — fix (two token changes, not one).** In `lib/Valiant/Validator/OnlyOf.pm`:
```perl
  my $count_not_blank = grep {
    defined $_ && ( $_ ne '' && $_ !~m/^\s+$/)
  } @group_values;
```
(Both changes are required: `$value`→`$_` AND `||`→`&&`. Swapping only the variable still leaves `''` counted, because `'' !~ /^\s+$/` is true.)

- [ ] **Step 4 — confirm pass.** `prove -l t/validator/only_of.t` → PASS.

- [ ] **Step 5 — commit.**
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add lib/Valiant/Validator/OnlyOf.pm t/validator/only_of.t
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Fix OnlyOf counting empty/whitespace values as filled\n\nThe blank check tested the current attribute value instead of the group member,\nand used || so it never excluded empty strings. Now excludes both "" and\nwhitespace-only siblings.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 5: `Check` validator crashes coderef + arrayref forms

**Files:** Modify `lib/Valiant/Validator/Check.pm`; Test `t/validator/check.t`.

- [ ] **Step 1 — failing test.** In `t/validator/check.t`, before `done_testing;`, add:
```perl
{
  ok eval {
    package Local::Test::Check::Dynamic;

    use Moo;
    use Valiant::Validations;
    use Types::Standard 'Int';

    has age => (is=>'ro');

    validates age => (
      check => { constraint => sub { Int->where('$_ >= 65') } },
    );

    1;
  }, 'a coderef constraint can be declared without crashing' or diag $@;
}

{
  ok my $object = Local::Test::Check::Dynamic->new(age=>80);
  ok $object->validate->valid;
}

{
  ok my $object = Local::Test::Check::Dynamic->new(age=>40);
  ok $object->validate->invalid;
}
```

- [ ] **Step 2 — confirm fail.** `prove -l t/validator/check.t` → first block dies at declare-time (`Can't call method "can" on unblessed reference`), so all three blocks fail.

- [ ] **Step 3 — fix.** Replace `Check.pm`'s `constraint` attribute (and add the `blessed` import):
```perl
package Valiant::Validator::Check;

use Moo;
use Valiant::I18N;
use Scalar::Util 'blessed';

with 'Valiant::Validator::Each';

has constraint => (is=>'ro', required=>1, isa=>sub {
  my $value = shift;
  my $ref = ref($value) || '';
  return if $ref eq 'CODE';
  my @constraints = $ref eq 'ARRAY' ? @$value : ($value);
  foreach my $constraint (@constraints) {
    die "constraint must be an object (or arrayref of objects) that can 'check'"
      unless blessed($constraint) && $constraint->can('check');
  }
});
has check => (is=>'ro', required=>1, default=>sub {_t 'check'});
```

- [ ] **Step 4 — confirm pass.** `prove -l t/validator/check.t` → PASS.

- [ ] **Step 5 — commit.**
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add lib/Valiant/Validator/Check.pm t/validator/check.t
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Fix Check validator isa guard for coderef and arrayref constraints\n\nThe isa sub called ->can on the raw value, dying on the documented coderef and\narrayref forms while being toothless for a blessed object lacking check(). Now\naccepts coderefs, validates each element of an arrayref, and rejects non-checkers.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 6: `Filter::Upper`/`Filter::UcFirst` clobber omitted attributes + warn

**Files:** Modify `lib/Valiant/Filter/Upper.pm` and `lib/Valiant/Filter/UcFirst.pm`; Test `t/filters/case.t`.

Note: the correct post-fix behavior is that an omitted filtered attribute ends up **`undef`** (matching `Lower.pm`'s existing behavior) with **no warning** — Moo applies defaults on `exists`, and the filter always makes the key exist, so this does NOT restore a configured `default`. The wins are: no uninitialized warning, and `''`→`undef`.

- [ ] **Step 1 — failing test.** In `t/filters/case.t`, extend the existing test model with two default-bearing attributes filtered by upper/uc_first, then capture warnings around construction (read the file to match its exact existing package/attribute names first). Add to the package's attribute/filter declarations:
```perl
  has 'nickname' => (is=>'ro', default=>'anon');
  has 'callsign' => (is=>'ro', default=>'anon');

  filters nickname => (upper => 1);
  filters callsign => (uc_first => 1);
```
and replace the existing construction + assertions with a warning-capturing version:
```perl
my @warnings;
my $user = do {
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };
  Local::Test::User->new(
    uc_first=>'john',
    upper=>'john',
    lower=>'JOHN',
    title=>'john NAPIORKOWSKI',
  );
};

is $user->uc_first, 'John';
is $user->upper, 'JOHN';
is $user->lower, 'john';
is $user->title, 'John Napiorkowski';
is $user->nickname, undef, 'an omitted upper-filtered attribute is left undef, not clobbered with ""';
is $user->callsign, undef, 'an omitted uc_first-filtered attribute is left undef, not clobbered with ""';
is_deeply \@warnings, [], 'omitting a filtered attribute does not raise an uninitialized-value warning';
```

- [ ] **Step 2 — confirm fail.** `prove -l t/filters/case.t` → the `nickname`/`callsign` are `''` (fail) and `@warnings` is non-empty (fail).

- [ ] **Step 3 — fix.** In BOTH `lib/Valiant/Filter/Upper.pm` and `lib/Valiant/Filter/UcFirst.pm`, add the undef guard `Lower.pm` already has:
```perl
sub filter_each {
  my ($self, $class, $attrs, $attribute_name) = @_;  
  my $value = $attrs->{$attribute_name};
  return unless defined $value;
  return uc $value;
}
```
(and `return ucfirst $value;` in `UcFirst.pm`)

- [ ] **Step 4 — confirm pass.** `prove -l t/filters/case.t` → PASS, zero warnings.

- [ ] **Step 5 — commit.**
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add lib/Valiant/Filter/Upper.pm lib/Valiant/Filter/UcFirst.pm t/filters/case.t
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Guard Filter::Upper/UcFirst against undef\n\nUnlike their 8 sibling filters, Upper/UcFirst lacked the undef guard, so an\nomitted filtered attribute got an explicit "" (clobbering its default) plus an\nuninitialized-value warning. Now they leave undef alone, like Lower.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 7: `errors->merge`/`import_error` lose error `type`

**Files:** Modify `lib/Valiant/Errors.pm`; Test `t/errors.t`.

- [ ] **Step 1 — failing test.** In `t/errors.t`, find the existing `import_error` usage:
```perl
$errors->errors->import_error($clone);
```
and after its existing assertions add:
```perl
my ($imported) = ($errors->errors->errors->all)[-1];
is $imported->raw_type, 'is always in error!',
  'import_error preserves the original error type instead of defaulting to invalid';
```
(`$clone` was cloned from the `with`-validator error whose type is the literal `'is always in error!'` — confirm that string against the file; if the cloned error's type differs, assert whatever `$clone->raw_type` actually is.)

- [ ] **Step 2 — confirm fail.** `prove -l t/errors.t` → FAILS (imported error's `raw_type` is the `invalid` tag today).

- [ ] **Step 3 — fix.** In `lib/Valiant/Errors.pm`, `sub import_error`, pass `type` through:
```perl
sub import_error {
  my ($self, $error, $options) = @_;
  $self->errors->push(
    my $nested_err = Valiant::NestedError->new(
      inner_error => $error,
      object => $error->object,
      attribute => $error->attribute,
      type => $error->type,
      %{ $options||+{} },
    )
  );
}
```

- [ ] **Step 4 — confirm pass.** `prove -l t/errors.t` → PASS (Task 1's assertions still pass too).

- [ ] **Step 5 — commit.**
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant add lib/Valiant/Errors.pm t/errors.t
git -C /Users/jnapiorkowski/Desktop/Valiant commit -m "$(printf 'Preserve error type through import_error/merge\n\nimport_error built a NestedError without a type, so BUILDARGS defaulted it to\ninvalid; the message still rendered (delegated to inner_error) but ->type was\nwrong. Pass type through, as copy() already does.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 8: Full suite + PR

- [ ] **Step 1 — full suite green.**
```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && prove -lr t 2>&1 | tail -6'
```
Expected: `Result: PASS`, zero warnings, file count unchanged from the pre-branch baseline (61 files).

- [ ] **Step 2 — push + PR.**
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant push -u origin fix-critical-validation-bugs
gh pr create --repo jjn1056/Valiant --base main --head fix-critical-validation-bugs \
  --title "Fix 7 critical validation bugs (with tests)" \
  --body "$(printf 'Fixes the 7 critical bugs from CODE-REVIEW.md, each with a regression test that fails before the fix:\n\n1. errors->added/of_kind for i18n-tag errors\n2. numericality pg_serial/pg_bigserial bounds + locale keys\n3. strict => class-name routing\n4. OnlyOf counting empty/whitespace as filled\n5. Check validator coderef/arrayref forms\n6. Filter::Upper/UcFirst undef guard\n7. import_error/merge preserving error type\n\nEach was reproduced live before fixing; the common thread was zero test coverage on the affected path, so each fix ships with a test closing that gap.\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)')"
```

- [ ] **Step 3 — CHECKPOINT: John reviews/merges the PR.**

---

## Notes carried from verification (do not re-derive)
- Bug #4 needs **two** token changes, not one (`$value`→`$_` and `||`→`&&`).
- Bug #6's fix yields `undef` for omitted attributes (NOT the configured default) — assert `undef` + no-warning, not default-preservation.
- Bug #3's fix **breaks** `t/strict.t` as written (it passes only due to the bug) — edit it in the same commit.
- Bug #2's two edits must land together or the `id=>0` case dies instead of failing.
- Test runner: `prove -l t/<file>.t` under the perlbrew wrapper.

## Out of scope (from the review, not this plan)
Extraction of `Valiant::HTML`; the `Valiant::Reform` layer; the JSON Catalyst-coupling fix; the ~20 non-critical bugs/smells and POD typos (incl. `Errors.pm`'s "inport" typo). Track separately.
