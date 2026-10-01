# Generated storefront compatibility tests

These tests accompany the compatibility changes inspired by upstream PR #127.
They do not cover multi-store credentials or cross-site SSO.

## Standalone plugin regression tests

From the plugin directory, using the installed host bundle:

```sh
BUNDLE_GEMFILE=/path/to/mall/Gemfile bundle exec rspec --options /dev/null spec/compatibility
```

The 12 examples require no database or dummy app. They exercise actual Rails
controller dispatch/callbacks and real temporary files. Registration uses a
minimal host resource contract; this is not a full legacy-storefront integration.
Distinct host/engine route sets detect incorrect route selection.

The generator tests found and guard against checking the process working
directory instead of the generator destination root.

GitHub Actions runs these standalone tests on Ruby 3.3 / Rails 7.2 and Ruby 4.0 /
Rails 8.1, using `spec/compatibility/Gemfile`. This workflow does not run the
host-dependent integration suite or the upstream legacy dummy-app suite.

## Host integration tests owned by this plugin

From a configured mall checkout that loads this plugin via its local path:

```sh
RAILS_ENV=test DATABASE_URL=postgresql://TEST_CONNECTION/mall_social_test bundle exec rspec ../solidus_social/integration/current_storefront_spec.rb
```

Use a disposable database with the mall schema and plugin migrations installed.
The test refuses to run without an explicit test database URL ending in `_test`.
The host must provide its `rails_helper`, Google/Facebook provider registration,
and the generated storefront login/signup/account views with social buttons.
An optional `SOCIAL_TEST_STATUS_PATH` overrides the host's example-status file.

The 13 examples exercise Google/Facebook callbacks, new and existing identities,
linking, missing-email registration, cancellation, login forms, missing credentials
and decorator loading. Only the external OAuth responses are simulated; Rails,
Devise and database persistence are real. Actual provider consent/token exchange
and the complete legacy dummy-app suite require separate verification.

The mall request suite is retained as host regression coverage; these overlapping
examples are not additional unique business scenarios or a coverage percentage.
