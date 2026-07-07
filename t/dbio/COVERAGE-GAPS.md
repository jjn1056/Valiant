# DBIO test lane — coverage gaps

Notes on under-tested behavior spotted while porting DBIC tests to the DBIO lane.
Ported test files are faithful mirrors of their `t/dbic/*.t` originals (no strengthened
assertions), so gaps noticed during porting are logged here instead of fixed in place.

- **i18n/locale message data was silently missing for `DBIO::Valiant`, and no
  Task 1-5 test caught it.** `lib/DBIO/Valiant/Validator/SetSize.pm` (`too_few`/
  `too_many`) and `lib/DBIO/Valiant/Result.pm` (`related_not_found`) both call
  `_t(...)` from `Valiant::I18N`, which resolves locale files relative to each
  module's own path (`lib/DBIO/Valiant/locale/*.pl`,
  `lib/DBIO/Valiant/Validator/locale/*.pl`). Those directories never existed —
  only the `lib/DBIx/Class/Valiant/**/locale/errors.pl` originals did — so any
  full-message rendering of a `too_few`/`too_many`/`related_not_found` error
  under DBIO would throw `Can't find a translation for key`. None of
  `t/dbio/00-env.t`, `component.t`, `exceptions.t`, `form-fields.t`, or
  `validates-role.t` exercise `errors->to_hash(full_messages=>1)` on a SetSize
  or related-not-found error, so the gap went undetected until `basic.t`
  (line 122) surfaced it. Fixed in this task by porting the two `errors.pl`
  files verbatim to `lib/DBIO/Valiant/locale/errors.pl` and
  `lib/DBIO/Valiant/Validator/locale/errors.pl` — logged here as a process
  note: any future validator/message-key addition to `lib/DBIO/Valiant/**`
  should carry at least one `full_messages=>1` assertion exercising it.

- **`is_unique` skip-on-unchanged-value optimization is not directly tested.**
  Per the dependency notes (`dbio-integration-notes.md` Part 1), `is_unique`
  does a `$source->resultset->single({col=>$val})` lookup that is *skipped*
  when the column value is unchanged on an already-in-storage row. `basic.t`
  only exercises the "changed to a duplicate value" create-path case
  (`username => 'jjn4'` collision around line 312) — nothing asserts the
  skip-when-unchanged path (e.g. updating an in-storage Person without
  touching `username` should not re-run the uniqueness query, or should not
  fail even if a concurrently-inserted duplicate now exists). This matters
  more once async lands (Task 14+): a validator that unnecessarily blocks the
  event loop on an unrelated update would be a real regression, and nothing
  today would catch it.

- **`TooManyRows` (SetSize `limit`) is only exercised via `create`, not
  `update`.** `basic.t` (~line 742) creates a Person with 3 credit_cards
  against a 2-row limit and asserts the exception; there is no equivalent
  test that triggers the same limit via `->update({credit_cards => [...]})`
  on an existing row. `t/dbio/exceptions.t` only unit-tests the exception
  class itself (`throw`/`catch`), not the limit-enforcement trigger. The
  update-path trigger for `TooManyRows` is therefore untested in the DBIO
  lane (and, for the record, in the DBIC lane's `t/dbic/basic.t` too — this
  predates the port).
