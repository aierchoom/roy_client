# Built-In Template Simplification Execution Report

| Item | Value |
|---|---|
| Status | Implemented |
| Date | 2026-04-28 |
| Scope | Client models, user docs, technical docs |

## Goal

Reduce the default built-in template set so SecretRoy feels lighter and more aligned with the trusted local-first sensitive information manager direction.

## Scope

Included:

- Keep one broad generic information template.
- Remove narrow built-ins from the default template list.
- Update documentation that describes built-in templates.

Out of scope:

- Template migration tooling.
- Compatibility wrappers for removed built-in template ids.
- UI redesign of the template page.

## Changes

- `basicAccountTemplates` now contains:
  - `generic_info`
- Removed default built-in templates for:
  - website/app accounts
  - bank cards
  - email accounts
  - phone numbers
- Added `genericInfoTemplate` as a compact sensitive information container with one hidden `content` field.
- Updated quick-start, user-manual, and technical documentation to reflect the reduced built-in set.
- Updated release-note copy so it describes the lighter built-in template surface.

## Validation

- `dart format lib/models/account_template.dart test/models/account_template_test.dart`
- `dart format lib/views/release_note_view.dart`
- `dart analyze lib/models/account_template.dart test/models/account_template_test.dart`: no issues
- `flutter test test/models/account_template_test.dart --reporter expanded --timeout 20s`: 3 passed after the follow-up sync-status fallback test was added
- `dart analyze lib test`: no issues
- `flutter test --reporter expanded --timeout 20s`: 54 passed after the follow-up app quality convergence tests were added

## Risk Notes

- Existing records that still reference removed built-in template ids can appear as missing-template records until the user retargets them to the generic information template or recreates those structures as custom templates.
- This is intentional for the current iteration because the roadmap favors a smaller default surface over broad preset coverage.

## Follow-Ups

- Consider adding a template-pack/import flow later if users want optional preset libraries without making every preset part of the default app surface.
