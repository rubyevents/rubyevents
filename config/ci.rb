# Run using bin/ci
# This file mirrors the GitHub Actions CI workflow in .github/workflows/ci.yml

CI.run do
  # Lint job - matches GitHub CI lint steps
  step "Lint: StandardRB Check", "bundle exec standardrb"
  step "Lint: StandardJS Check", "yarn lint"
  step "Lint: YAML data files", "yarn lint:yml"
  step "Lint: erb-lint Check", "bundle exec erb_lint --lint-all"

  step "Security: Gem audit", "bin/bundler-audit"

  # Test job - matches GitHub CI test steps
  step "Setup: Install yarn dependencies", "yarn install --frozen-lockfile"
  step "Setup: Build assets", "bin/vite build --clear --mode=test"
  step "Setup: Prepare database", "bin/rails db:test:prepare"
  step "Tests: Rails", "bin/rails test"
  step "Tests: System", "bin/rails test:system"

  # Seed smoke test job - matches GitHub CI seed_smoke_test steps
  step "Tests: Seed Smoke Test", "SEED_SMOKE_TEST=true bin/rails test test/tasks/db_seed_test.rb"
  step "Tests: Verify all thumbnails for child talks are present", "bin/rails verify_thumbnails"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
