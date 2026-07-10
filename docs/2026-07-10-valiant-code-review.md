# Valiant — Code Review (2026-07-10)

Honest, opinionated review of core `Valiant` after the DBIx::Class / DBIO / Catalyst
extractions. Bugs marked **[verified]** were reproduced live against the shipped code
under `perl-5.40.0@default`, not inferred from reading.

---

## Executive verdict

**Strong bones, ambitious and genuinely faithful to Rails — but under-tested at the edges
and over-scoped, with a real backlog of shipped bugs in documented "Rails-parity" features.**

The design is 1.0-quality: the `Validator`/`Each` split, the validator-namespace resolution,
the global-options/context system, and the i18n message cascade are serious, correct ports of
Rails `ActiveModel`. The DSL is ergonomic and reads like Rails. The nested-object validation is
actually *better* than Rails' `validates_associated`. Someone who knows Rails deeply wrote this.

The *polish* is late-beta, not 1.0. Across the four subsystems the review found ~27 concrete
issues, and the headline ones aren't nitpicks — they're shipped, documented features that don't
work: `errors->added`/`of_kind` (Rails' `errors.added?`) is 100% broken for tag-typed errors;
`strict => 'Exception::Class'` never routes; `numericality => 'pg_serial'` only accepts the value
`0` and then crashes when you render the error; `OnlyOf` treats `''` as filled (i.e. breaks on the
exact shape of real form submissions); the `Check` validator crashes 2 of its 3 documented forms.
**The common thread: almost every verified bug lives in a code path with zero test coverage.**
The test suite is sizable (~100 files) but has systematic blind spots precisely where the bugs are
— empty strings, coderef/arrayref forms, undef, nested attributes, the shortcut variants.

And it's doing too much for one distribution: validation + attribute filtering + errors/i18n + a
~7,000-line HTML forms/templating engine + a JSON builder + proxies. Now that the ORM and Catalyst
glue is gone, the HTML layer is the single largest thing in the tree and reads as a different
concern.

Net: a very good library that thinks it's further along than it is. A focused bug-fix + test pass
on the list below would move it a long way toward deserving the "1.0" its design implies.

---

## What's genuinely good (credit where due)

- **Rails fidelity where it counts.** `Validator`/`Each`, custom-validator lookup
  (`Valiant::ValidatorX::*` third-party vs `Valiant::Validator::*` shipped), `on`/`if`/`unless`/
  `strict`/`allow_blank`/`allow_undef`/`message` global options, and contexts — all faithful.
- **The i18n subsystem is a serious port** of Rails' scoped-key fallback cascade + pluralization
  (`zero`/`one`/`other`) + `{{placeholder}}` interpolation. One of the best-built parts.
- **Nested-object validation beats Rails.** Failures flatten onto dotted/bracketed paths
  (`address.city`, `car[0].make`) instead of Rails' single generic associated-error.
- **`SafeString` (XSS) is correct** — escape-on-render, mark-safe-when-safe, fails closed on
  `+`, handles the nasty JSON-in-HTML-attribute case. The strongest single file in the codebase.
- **`as_rfc_7807`** error formatting is a real value-add over Rails (which ships none).
- **`Proxy`** (validate metadata-less data) is small, clean, and reuses the real validation engine.
- **The shortcut ladder** (`presence => 1`, `length => [3,20]`) → full hashref is good ergonomics.
- Perl 5.20 compatibility is actually honored throughout `lib/`.

---

## The architecture question (this is the important part)

### 1. Extract the HTML layer → its own dist
`lib/Valiant/HTML/**` is ~7,000 lines — the largest namespace in the tree, a Rails-`ActionView`-
scale forms/templating engine. Crucially, its coupling to the validation core is **loose and
duck-typed**: zero hard `use` of `Valiant::Errors`/`Validates`/`Validations`; only three tiny
touchpoints (`I18N`, `Naming`, `Util`) and a documented "REQUIRED MODEL API" contract. So this is
a **cohesion** call, not a forced-dependency one like the ORMs were — but it's the same
inconsistency: a validation library shouldn't have a 7K-line form builder as its biggest component.
Clean seam, low-risk mechanical extraction (`Valiant::HTML` depends on `Valiant`, not the reverse).
Keep `SafeString` in core (nothing depends *up* from it; JSON/error-rendering may want it).

### 2. The Reform-style form-object layer (the genuinely valuable evolution)
The form logic — accept params, coerce/filter, validate, handle nested has-many/has-one, sync to
storage — currently lives **inside the ORM integrations** (`accept_nested_for`, nested create/update).
That's the wrong home; it isn't about DBIC/DBIO, it's about a *form object mediating between
untrusted params and one-or-more models*, and it's why that code was the gnarliest in the codebase.
A `Valiant::Reform`-ish layer would own it, ORM-agnostic, with the ORMs as thin **sync adapters** and
HTML `FormBuilder` as the **renderer**. The raw materials already exist, just entangled: `Proxy`
(proto form-object), the `Filter` system (coercion), the nested-param machinery. Target layering:
`Valiant` (validation) → `Valiant::Reform` (form objects) → `Valiant::HTML` + ORM adapters.
Caveat: real design effort, and needs a deliberate stance on whether form objects **supersede** or
**complement** the model-attached (ActiveModel) style — supporting both well is where these bloat.

### 3. Fix the JSON layering violation **[verified]**
`Valiant::JSON::JSONBuilder::_errors_for` (JSONBuilder.pm:401) hardcodes Catalyst
(`$self->view->ctx->req->content_type`) inside the *framework-agnostic* `Valiant::JSON` namespace —
a direct violation of the layer-2/layer-4 boundary in your own CLAUDE.md. `->errors` on a non-Catalyst
JSONBuilder blows up. Zero test coverage. Move it to the Catalyst view layer or inject the dependency.

### 4. Filters: decide coerce-vs-DSL, and document the sharp limitation
`Valiant::Filterable` runs filters **only at construction, never on later writes** — an `rw`
attribute set via `$obj->name(...)` or a DBIC `update`/`set_column` is *not* re-filtered. That's a
different contract than Rails' `before_validation`, and a real footgun for the DBIC use case this was
built around. It also reimplements, more narrowly, what Moo/Type::Tiny `coerce => 1` already does on
every set. Keep filters (they're useful + well-tested), but document the construction-only limit
prominently, and decide deliberately whether new filters should be Type::Tiny coercions instead.

---

## Verified bugs, ranked

### Critical — shipped/documented features that don't work
1. **`errors->added` / `errors->of_kind` non-functional for i18n-tag errors** **[verified]** —
   `Error::strict_match` (Error.pm:324) does `FreezeThaw::cmpStr(\%options, undef)` when no options
   are passed; a hashref never structurally equals `undef`, so it always returns false for any error
   carrying interpolation options (`count`/`minimum`/… — i.e. nearly all of them). This is Rails'
   `errors.added?`. Fix: `return 1 unless defined $options;` before the compare.
2. **`numericality => 'pg_serial'` / `'pg_bigserial'` broken + crash-prone** **[verified]** —
   Numericality.pm:70-79 sets `>= 0` **and** `<= 0`, so only the literal `0` validates (serials start
   at 1). And the message tags it references (`pg_serial_err`) don't exist in
   Validator/locale/errors.pl (which has `pg_serial`, no `_err`), so rendering the error throws an
   uncaught "Can't find a translation" and crashes.
3. **`strict => 'Some::Exception::Class'` never routes** **[verified]** — Errors.pm:253:
   `if (ref(\$exception) eq 'SCALAR')` is true for *any* plain string, intercepting the documented
   class-name mode before it reaches `$exception->throw($message)`. Fix: drop the stray backslash, or
   delete the branch (the later line already handles both string and object).
4. **`OnlyOf` counts blank fields as filled** **[verified]** — OnlyOf.pm:32 tests the outer `$value`
   instead of `$_`; the predicate collapses to `defined($_)`, so a sibling field holding `''`
   (the normal HTML-form case) counts as present. One-char fix.
5. **`Check` validator crashes 2 of 3 documented forms** **[verified]** — Check.pm:8's
   `isa => sub { shift->can('check') }` dies on a coderef or an arrayref of constraints (both
   documented), and is toothless for a blessed object lacking `check`.
6. **`Filter::Upper` / `Filter::UcFirst` clobber attribute defaults + warn** **[verified]** —
   Upper.pm:13 / UcFirst.pm:13 are missing the `return unless defined $value;` guard all 8 sibling
   filters have. Because filters run at BUILDARGS (before Moo defaults apply), an unsupplied filtered
   attribute gets an explicit `''`, silently overriding its `default`/`builder`, plus an uninit
   warning. Two-line fix.
7. **`errors->merge` / `import_error` silently lose error `type`** **[verified]** — Errors.pm:76-86
   builds a `NestedError` without passing `type`, so `Error::BUILDARGS` defaults it to `invalid`;
   `->message` still renders right but `->type` is wrong. `copy()` does this correctly — the two paths
   are inconsistent. (Compounds bug #1.)

### Important
8. **`Length` silently drops the per-call options hash** **[verified]** — Length.pm:28-31 discards
   the 5th positional arg; extra data passed to `->validate(...)` reaches a Presence error's options
   on the same call but not a Length error. Format/Numericality/Date/Presence thread it correctly.
9. **`Translation::human_attribute_name`/`human_label_name` nested branch is dead code** **[verified]**
   — Translation.pm:31,83 use `split '.', $attribute` (bare `.` matches any char → always empty list),
   so the `model/namespace`-scoped human-name lookup for nested attributes (`profile.name`) can never
   fire. `Error::full_message` gets the same thing right with `split '\.'`. (And the dead branch has a
   second `$attribute` vs `$attribute_name` bug if fixed.)
10. **`form_enctype` returns the wrong attribute** **[verified]** — FormBuilder.pm:62 returns
    `->options->{html}{method}` (copy-paste of `form_method`), not `enctype`.
11. **`validated` / `skip_validation` are constructor-settable** — Validates.pm:88-89 use
    `init_args=>undef` (plural typo; the valid option is `init_arg`), so both silently accept a
    constructor value they shouldn't.
12. **Two incompatible nested-index conventions** — `full_message` strips both `\.\d+` and `\[\d+\]`
    (Error.pm:110-111); `generate_message` strips only `\[\d+\]` (Error.pm:182). A locale file that
    satisfies one won't satisfy the other for the same nested attribute.

### Minor (smells / warnings / dead code)
13. `Format`'s `without` lacks the undef guard `match` has (Format.pm:181) → uninit warning. **[verified]**
14. `Numericality`'s `decimals` uses `length(undef)` (Numericality.pm:21) → uninit warning. **[verified]**
15. `Error::match` iterates `%{$options}` instead of `keys %{$options}` (Error.pm:295). **[verified]**
16. `Errors::uniq { die 'todo' }` — shipped public stub (Errors.pm:45).
17. `Array.pm:59` / `Hash.pm:62` — identical `$errors->{__result} = $result; # hack` reaching into
    another blessed object's hash to defeat a weak ref.
18. `Proxy::Object::AUTOLOAD` swallows unknown method calls (Object.pm:24, `warn` commented out) →
    typos return `undef` instead of failing loudly.
19. Dead files: `Tag.pm` + `Tag/Label.pm` (234 lines, `TBD` POD, no-op test with leftover
    `Devel::Dwarn`). Finish or delete.
20. Dead code: FormBuilder.pm:255-256 (duplicate `return`); FormTags.pm:451-455 (commented method);
    Scalar.pm:17 (dead disjunct).
21. Unbounded, never-invalidated process-global cache `%_sanitized_name_cache` (FormTags.pm:370).
22. `inject_attribute` (Validates.pm:398-401) does `eval "package $class; has ..."` with no `$@` check.

### Documentation bugs (these violate the project's own "document in the same commit" rule)
23. `skip_validate` / `do_validate` POD is **backwards** relative to the code (Validates.pm).
24. `field()` / `FormBuilder::Proxy` (FormBuilder.pm:1185-1283) — shipped, tested, **zero POD**;
    the code itself says "prototype status and undocumented."
25. `Array.pm` validator POD shows dot notation (`car.0`) but the code produces bracket (`car[0]`).
26. `Proxy::*` docs — the Array proxy's POD says "hashref", stale `Valiant::Result::*` package titles,
    phantom `result_class`/`meta_class` attributes that don't exist, `TBD` synopses in all three.
27. Scattered POD typos ("Addos", "valiates_with", "vadate_only", "I saw now reason", a stray `ß`).

---

## Missing vs Rails
1. **`acceptance`** — no dedicated "must accept checkbox/terms" validator (approximable, loses ergonomics).
2. **Cross-attribute `comparison`** (`greater_than: :start_date`) — only via hand-written coderef today;
   `Numericality` has all the operators but no attribute-to-attribute mode, `Date`'s min/max is coderef-only.
3. **Collection-level `errors.details`** — per-error `detail` exists (Error.pm:271), nothing aggregates it.
4. Bare `validate :method` one-liner — has slightly-more-boilerplate equivalents (`validates_with`).

Note: with the Perl-specific additions (`Check`, `With`, `Scalar`, `OnlyOf`, `Boolean`) the validator
set otherwise covers, and in the nested case exceeds, Rails' built-ins.

---

## Cross-cutting patterns worth fixing at the root
- **Copy-paste divergence between sibling classes is the #1 bug source** — Upper/UcFirst vs 8 siblings,
  Proxy::Array POD vs Proxy::Hash, Translation's `split '.'` vs Error's correct `split '\.'`,
  Util/Form vs Util/Pager. A shared-behavior test ("every simple filter handles undef identically") +
  `perlcritic` in CI would catch most of these mechanically.
- **Untested branches strongly correlate with the bugs** — `of_kind`'s tag branch, `_errors_for`'s
  Catalyst path, the nested-namespace branch, pg_serial, Check's coderef form, OnlyOf-with-`''`: all
  zero-coverage. Coverage gaps here are a *leading indicator*, not incidental. Highest-value lever.
- **`ref()`-type implicit dispatch** is a consistent house idiom (is it a CODE/SCALAR/tag/hash?) that's
  very Perl but carries real cognitive cost (Error.pm's `message()` needs a paragraph to trace).

## Suggested order of attack
1. Fix the 7 Critical bugs — all small, all in shipped documented features, all high embarrassment.
2. Add tests for exactly those paths (empty string, coderef/arrayref, undef, nested, shortcut variants)
   — this is where the leverage is.
3. Documentation pass: the doc-vs-code mismatches (#23–27), then a typo sweep.
4. Extract `Valiant::HTML` to its own dist (keep `SafeString`); fix the JSON Catalyst coupling.
5. Prototype the `Valiant::Reform` form-object layer; pull nested-attribute logic out of the ORM dists.
