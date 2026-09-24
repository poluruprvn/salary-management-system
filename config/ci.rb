# Run using bin/ci

CI.run do
  step "Setup", "SEED_EMPLOYEE_COUNT=50 bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Tests: Ruby", "bundle exec rspec"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Docs: OpenAPI up to date", "RAILS_ENV=test bin/rails rswag && git diff --exit-code swagger/"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
