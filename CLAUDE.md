# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Valiant is a CPAN distribution providing Ruby-on-Rails-inspired domain-level validation for Moo/Moose classes, plus attribute filtering, i18n error messages, and HTML/JSON generation. It ships only the `Valiant::*` namespace. The ORM and web-framework integrations live in sibling repositories/distributions: `DBIx-Class-Valiant` (DBIC glue), `DBIO-Valiant` (async DBIO glue), and `Catalyst-View-Valiant` (experimental Catalyst views) — all under `~/Desktop/` and on jjn1056's GitHub.

## Commands

```bash
cpanm --installdeps .        # install dependencies (from cpanfile)
prove -lr t                  # full test suite
prove -l t/validates.t       # single test file (-v for verbose)
prove -lr t/validator        # one test area (validator, filters, html, json, examples)
```

Tests need no external services.

Releases are built with Dist::Zilla: version and metadata live in `dist.ini`, dependencies come from `cpanfile` via Prereqs::FromCPANfile. Record user-visible changes in `Changes` (hand-maintained). `README.mkdn` is generated from the POD in `lib/Valiant.pm` — edit the POD, not the README.

## Perl Compatibility

CI tests Perl 5.20 through latest. Code in `lib/` deliberately avoids `use feature`/`use v5.x` pragmas and post-5.20 syntax (no subroutine signatures, etc.) — keep new library code compatible with Perl 5.20.

## Architecture

Two layers; the second depends only on the first.

### 1. Core validation and filtering (`lib/Valiant/`)

- The role/DSL pair pattern: `Valiant::Validates` is a Moo::Role holding the actual validation API and class metadata; `Valiant::Validations` is the importable DSL (`validates`, `validates_with`) that applies the role. Filtering mirrors this exactly: `Valiant::Filterable` (role) / `Valiant::Filters` (DSL, `filters`, `filters_with`). Filters run on attribute values at object construction; validations run on demand via `$obj->validate`.
- Validators are classes under `Valiant::Validator::*`, most subclassing `Valiant::Validator::Each` (per-attribute). Resolution for `validates name => (length => ...)`: the consuming class's own namespace is checked first, then `Valiant::ValidatorX::*` (reserved for third-party CPAN validators), then `Valiant::Validator::*` (reserved for validators shipped here). Filters resolve identically under `Valiant::FilterX::*` / `Valiant::Filter::*`.
- Errors accumulate in `Valiant::Errors` (a collection of `Valiant::Error`). Error messages are i18n tags resolved through `Valiant::I18N` (Data::Localize); default English messages live in `lib/Valiant/locale/errors.pl`.
- `Valiant::Proxy` (and `::Object`, `::Hash`, `::Array`) builds validation rulesets dynamically at runtime, for validating data/objects that carry no validation metadata of their own.
- Validation contexts (`on => 'registration'`) let one class hold rules that apply only in certain situations.

### 2. HTML and JSON generation (`lib/Valiant/HTML/`, `lib/Valiant/JSON/`)

Layered from low to high: `Valiant::HTML::Util::TagBuilder` (raw tags) → `Valiant::HTML::Util::FormTags` (form controls) → `Valiant::HTML::Util::Form` / `Valiant::HTML::FormBuilder` (model-aware forms that read attribute values and render validation errors from any object doing the Valiant roles). `Valiant::HTML::SafeString` handles escaping/marking of safe output. `Valiant::HTML::Util::Pager` + `Valiant::HTML::PagerBuilder` render pagination. `Valiant::JSON::JSONBuilder` is the same model-aware-builder idea for JSON.

### Split-out integrations (separate distributions, NOT in this repo)

The DBIC components (`DBIx::Class::Valiant::Result`/`ResultSet`, nested writes via `accept_nested_for`, validators `Result`/`ResultSet`/`SetSize` under `DBIx::Class::Valiant::Validator::*` — note `unique => 1` resolves to core `Valiant::Validator::Unique` plus an `is_unique` method, there is no DBIC-specific Unique validator) live in the `DBIx-Class-Valiant` repo; `DBIO-Valiant` is its asynchronous (Future-based) port for DBIO; `Catalyst-View-Valiant` (experimental, tabled) holds the per-request Catalyst views. Work on integration code happens in those repos.

## Tests

- `t/lib/` holds test support code: `Person`/`Retiree` sample Moo classes, local validators, and views. Tests load it with `Test::Lib`.
- Test layout mirrors the architecture: core `t/*.t`, one file per shipped validator in `t/validator/`, plus `t/filters/`, `t/html/`, `t/json/`, and runnable doc examples in `t/examples/`.

## example/ Directory

A complete demo Catalyst CRUD application (pruned from the release tarball via `dist.ini` because its views depend on the split-out `DBIx::Class::Valiant` and `Catalyst::View::Valiant` distributions). It has its own `cpanfile`, sqitch DB migrations, and a `Makefile` (`make server` to run it). It is not part of the main test suite.
