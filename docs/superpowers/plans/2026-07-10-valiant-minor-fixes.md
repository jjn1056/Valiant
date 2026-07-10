# Valiant — Minor Fixes + Small Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Fix the non-critical bugs from the code review (`docs/2026-07-10-valiant-code-review.md`), add two small missing features (`acceptance`, `errors->details`), implement the `uniq` stub, and clean up dead code + docs. Excludes anything Catalyst/JSON-related (tabled) and the HTML-extraction / Reform / filter-rerun design work.

**Architecture:** One branch (`minor-fixes`), TDD per behavior bug / feature (failing test → fix → pass → commit), grouped commits for pure cleanup and for docs, then a full-suite gate + PR.

## Global Constraints
- perlbrew wrapper for perl/prove: `bash -c 'source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && <cmd>'`. Single test: `prove -l t/<file>.t`.
- **True TDD** for behavior/features: write the test, CONFIRM IT FAILS, then fix.
- Perl 5.20 compat; pristine output (no warnings); never `git add -A`; commit trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Core changes → branch + PR (not pushed to main).
- **Decisions already made with John:** `uniq` → IMPLEMENT (not remove); `Proxy::Object` AUTOLOAD → fail loud (⚠️ behavior change); nested-index → reconcile to bracket (⚠️ locale-lookup, careful test); `__result` hack + unbounded `%_sanitized_name_cache` → leave as-is (accepted); `comparison` → document the existing coderef pattern, do NOT build a new validator.
- Each fix's exact old-text is read from the file at execution time; file:line and the change are given below.

---

### Task 0: Branch
```bash
git -C /Users/jnapiorkowski/Desktop/Valiant checkout main && git -C /Users/jnapiorkowski/Desktop/Valiant pull --ff-only
git -C /Users/jnapiorkowski/Desktop/Valiant checkout -b minor-fixes
```

### Task 1: `Length` forwards per-call options  (TDD)
- **Fix:** `lib/Valiant/Validator/Length.pm:28-31` — `validate_each` destructures `($self,$record,$attribute,$value)` and drops the 5th arg; add `$opts` and merge it into `%opts` (mirror `Presence`/`Format`, which thread `$opts`).
- **Test:** `t/validator/length.t` — a validation where a per-call `->validate(foo=>'bar')` option must appear in the Length error's `options` (assert it's threaded, like Presence does).

### Task 2: `Translation` nested-attribute human name  (TDD)
- **Fix:** `lib/Valiant/Translation.pm:31` and `:83` — `split '.', $attribute` → `split '\.', $attribute`; and in the `if($namespace){...}` branch interpolate `${attribute_name}` (the popped last segment), not `${attribute}`.
- **Test:** `t/i18n.t` (or `t/human.t`) — a model with a translated nested attribute name (`profile.name`) resolves to the model/namespace-scoped human name, not the generic fallback.

### Task 3: `form_enctype` returns the right attribute  (TDD)
- **Fix:** `lib/Valiant/HTML/FormBuilder.pm:62` — `sub form_enctype { shift->options->{html}{method} }` → `{enctype}`.
- **Test:** `t/html/form-builder.t` — build a FormBuilder with `html => { enctype => 'multipart/form-data', method => 'post' }`; assert `form_enctype` returns the enctype, `form_method` the method.

### Task 4: `validated`/`skip_validation` not constructor-settable  (TDD)
- **Fix:** `lib/Valiant/Validates.pm:88-89` — `init_args=>undef` → `init_arg=>undef` on both attributes.
- **Test:** a validating class where `->new(validated=>1)` / `->new(skip_validation=>1)` is rejected (unknown constructor arg) — assert `validated` stays 0 / the constructor dies on the unknown key.

### Task 5: undef-value warnings in `Format` and `Numericality`  (TDD)
- **Fix a:** `lib/Valiant/Validator/Format.pm:181` — guard the `without` match with `defined($value) &&` (mirror the `match` branch at :176-177).
- **Fix b:** `lib/Valiant/Validator/Numericality.pm:21` — guard the `decimals` `length(($_[0]=~/\.(\d*)/)[0])` so a value with no decimal point doesn't `length(undef)`.
- **Test:** `t/validator/format.t` + `t/validator/numericality.t` — validate an undef value (no `allow_undef`) with `without` / `decimals` respectively, capturing `$SIG{__WARN__}`; assert zero warnings (same capture style as `t/filters/case.t`). One commit.

### Task 6: `Error::match` iterates keys  (TDD if feasible, else fix + suite-green)
- **Fix:** `lib/Valiant/Error.pm:295` — `foreach my $key (%{$options||+{}})` → `foreach my $key (keys %{$options||+{}})`.
- **Test:** `t/error.t` — a `where`/`match` call with a 2-key options filter that today mis-iterates; assert correct match/no-match. If a discriminating case is hard to construct, fix and rely on the full suite staying green.

### Task 7: Implement `Errors::uniq`  (TDD)
- **Fix:** `lib/Valiant/Errors.pm:45` — replace `sub uniq { die 'todo' }` with a real dedup using `Valiant::Error::equals` (Error.pm:328):
```perl
sub uniq {
  my $self = shift;
  my @uniq;
  foreach my $error ($self->errors->all) {
    push @uniq, $error unless grep { $_->equals($error) } @uniq;
  }
  return @uniq;
}
```
- **Test:** `t/errors.t` — add the same error (attribute + type + options) twice, assert `scalar($errors->uniq)` collapses the duplicate while distinct errors are kept. Add POD for `uniq` in Errors.pm.

### Task 8: `acceptance` validator  (TDD + POD + locale)
- **Files:** create `lib/Valiant/Validator/Acceptance.pm`; add an `accepted` message to `lib/Valiant/locale/errors.pl` (or `Validator/locale/errors.pl` to match where validator messages live); test `t/validator/acceptance.t`.
- **Sketch** (finalize against a sibling like `Boolean.pm`/`Presence.pm` for exact role wiring):
```perl
package Valiant::Validator::Acceptance;
use Moo;
use Valiant::I18N;
with 'Valiant::Validator::Each';

has accept  => (is=>'ro', required=>1, default=>sub { ['1', 1, 'true', 'yes'] });
has message => (is=>'ro', required=>1, default=>sub { _t 'accepted' });

sub normalize_shortcut {  # `acceptance => 1`
  my ($class, $arg) = @_;
  return +{};
}

sub validate_each {
  my ($self, $record, $attr, $value, $opts) = @_;
  my %accept = map { $_ => 1 } @{ $self->accept };
  $record->errors->add($attr, $self->message, $opts)
    unless defined($value) && $accept{$value};
}
1;
```
- **Locale:** `accepted => 'must be accepted'`.
- **Test:** a non-persisted `agree_to_terms` attribute; `acceptance => 1` — passes when value is `'1'`, fails when `'0'`/undef; `acceptance => { accept => ['on'] }` custom list.
- **POD:** document the validator + shortcut form (same shape as other validators).

### Task 9: `errors->details` aggregator  (TDD + POD)
- **Fix:** add to `lib/Valiant/Errors.pm` (mirrors `to_hash`, using the existing `Error->detail` at Error.pm:271 which returns `{ error => $type, %options }`):
```perl
sub details {
  my $self = shift;
  my %details;
  foreach my $error ($self->errors->all) {
    my $attr = defined($error->attribute) ? $error->attribute : '*';
    push @{ $details{$attr} }, $error->detail;
  }
  return %details;
}
```
- **Test:** `t/errors.t` — a model with a couple of typed errors; assert `+{ $obj->errors->details }` groups `{ attr => [ { error => <type>, %opts } ] }`. (Confirm `Error->detail`'s exact key/shape by reading Error.pm:271 first.)
- **POD:** document `details` in Errors.pm.

### Task 10: `Proxy::Object` AUTOLOAD fails loud  ⚠️ behavior change  (TDD)
- **Fix:** `lib/Valiant/Proxy/Object.pm:18-26` — AUTOLOAD currently returns undef (the `warn` is commented). Make an unknown delegated method `die` with a clear "no such method on wrapped object" message (skip `DESTROY`/`can`). ⚠️ This changes behavior for anyone relying on silent-undef — John approved.
- **Test:** `t/proxy.t` — a Proxy::Object over an object; calling a method the wrapped object *has* still delegates; calling an unknown one now dies. (Read the file first — preserve whatever legitimate delegation it does.)

### Task 11: Reconcile nested-index conventions to bracket  ⚠️ careful  (TDD)
- **Fix:** `lib/Valiant/Error.pm` — `full_message` strips both `\.\d+` and `\[\d+\]` (:110-111) while `generate_message` strips only `\[\d+\]` (:182). Make `generate_message` also strip `\.\d+` so both build the same namespace for a nested-indexed attribute. ⚠️ This affects locale-key lookup — add a test that a nested-indexed attribute (`credit_cards[0].number`) resolves the same message via both paths, and run the full DBIC-style nested suites in the *plugin* repos are NOT in scope here (they're separate dists now) — just assert core behavior.
- **Test:** `t/error.t` or `t/i18n.t` — a nested-indexed attribute error renders the expected message + full_message consistently.

### Task 12: Dead-code cleanup  (suite-green, one commit)
- Remove `lib/Valiant/HTML/Tag.pm` + `lib/Valiant/HTML/Tag/Label.pm` (unused, `TBD` POD) and the no-op `t/html/tag.t` (`ok 1; done_testing; __END__` with leftover `Devel::Dwarn`). Confirm nothing references them first: `grep -rn 'Valiant::HTML::Tag\b\|HTML::Tag::Label' lib t`.
- Remove dead lines: `FormBuilder.pm:255-256` (duplicate `return`), `FormTags.pm:451-455` (commented-out `field_label`), `Scalar.pm:17` (dead second disjunct `ref(\(my $val=$value)) eq 'SCALAR'`).
- `Validates.pm:398-401` — `inject_attribute` does `eval "package $class; has ...";` with no error check; add `die $@ if $@;` after the eval.
- Verify: `prove -lr t` green.

### Task 13: Documentation  (one commit)
- `Validates.pm` POD — swap the `skip_validate` / `do_validate` descriptions (currently backwards vs the code).
- `FormBuilder.pm` — add a short `=head2 field` (or an `=head2 EXPERIMENTAL` note) documenting `field()`/`FormBuilder::Proxy` as experimental, so the shipped+tested surface isn't undocumented.
- `Array.pm` validator POD — change the nested-key examples from dot (`car.0`) to bracket (`car[0]`) to match the code.
- `Proxy/{Object,Hash,Array}.pm` + `Proxy.pm` POD — fix stale `Valiant::Result::*` names, the Array proxy's "hashref" wording, remove the phantom `result_class`/`meta_class` attribute docs, and fill the `TBD` synopses.
- `Filter.pm` / `Filterable.pm` POD — prominently document the **construction-only** limitation (filters do NOT re-run on `rw` writes or DBIC `update`/`set_column`).
- `Numericality.pm` / `Date.pm` POD — document the **coderef cross-attribute comparison** pattern (`greater_than => sub { shift->other_attr }`).
- POD typo sweep: "Addos"→"Adds" (Validations.pm), "valiates_with", "vadate_only" (Validates/Validations), "inport"→"import" (Errors.pm), stray `ß` (Validates.pm `context` POD).
- Verify: `prove -lr t` green (docs don't break tests, but the doc-example tests in `t/examples/` might).

### Task 14: Full suite + PR
```bash
bash -c 'cd /Users/jnapiorkowski/Desktop/Valiant && source ~/perl5/perlbrew/etc/bashrc && perlbrew use perl-5.40.0@default && prove -lr t 2>&1 | tail -6'
git -C /Users/jnapiorkowski/Desktop/Valiant push -u origin minor-fixes
gh pr create --repo jjn1056/Valiant --base main --head minor-fixes --title "Non-critical fixes: bugs, uniq, acceptance, errors->details, docs" --body "<summary of tasks; note the 2 flagged behavior changes: Proxy::Object AUTOLOAD fails loud; nested-index reconciled to bracket>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

## Out of scope (tabled / separate)
Catalyst::View::Valiant + the JSON `_errors_for` coupling; HTML extraction; `Valiant::Reform`; the filter-rerun-on-validate design change; the `__result` weak-ref hack; the unbounded `%_sanitized_name_cache`; a dedicated `comparison` validator (coderef pattern documented instead).
