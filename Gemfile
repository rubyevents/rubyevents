source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby file: ".ruby-version"

# Use main development branch of Rails from github
gem "rails", "8.1.1"

# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"

# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1.0"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma"

# use jbuilder for the api
gem "jbuilder"

# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
# gem "jsbundling-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
# gem "stimulus-rails"

# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
# gem "cssbundling-rails"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", "2.7.0", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Image processing for event asset generation
gem "mini_magick"

# All sorts of useful information about every country packaged as convenient little country objects
gem "countries"

# ISO 639-1 and ISO 639-2 language code entries and convenience methods
gem "iso-639"

# A minimal client of Bluesky/ATProto API
gem "minisky", "~> 0.4.0"

# Extract Collaborator Objects from your Active Records, a new concept called Associated Objects
gem "active_record-associated_object"

# Headless Chrome driver for Capybara
gem "cuprite"

# Reusable modules for tasks like data extraction, scoring, and ranking
gem "active_genie"

# A single delightful Ruby way to work with AI.
gem "ruby_llm", "~> 1.9.1"
gem "ruby_llm-schema"

# JSON Schema validator
gem "json_schemer"

# YouTube V3 API client.
gem "yt"

# Family of libraries that support various formats of XML "feeds".
gem "rss", "~> 0.3.1"

# Powerful and seamless HTML-aware ERB parsing and tooling.
gem "herb", "~> 0.8"

# An ActionView-compatible ERB engine with modern DX - re-imagined with Herb.
gem "reactionview", "~> 0.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[mri windows]
  gem "byebug"
  gem "minitest-difftastic", "~> 0.2"
end

group :development do
  gem "annotaterb"
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  gem "rack-mini-profiler"

  # For call-stack profiling flamegraphs
  gem "stackprof"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  # Use listen to watch files for changes [https://github.com/guard/listen]
  gem "listen", "~> 3.5"

  # Guard for watching file changes and auto-importing [https://github.com/guard/guard]
  gem "guard"

  gem "ruby-lsp-rails", require: false
  gem "standardrb", "~> 1.0", require: false
  gem "erb_lint", require: false
  gem "authentication-zero", require: false
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "rails-controller-testing"
  gem "selenium-webdriver"
  gem "vcr", "~> 6.1"
  gem "webmock"
end

gem "pagy"

# gem "activerecord-enhancedsqlite3-adapter"
gem "solid_cache"
gem "solid_queue", github: "joshleblanc/solid_queue", branch: "async-mode"
gem "mission_control-jobs"

gem "ahoy_matey"
gem "vite_rails"
gem "meta-tags"
gem "groupdate"
gem "appsignal"
gem "chartkick", "~> 5.0"
gem "dotenv-rails"

gem "rails_autolink", "~> 1.1"

gem "sitemap_generator", "~> 6.3"

gem "view_component"

gem "dry-initializer-rails"

gem "dry-types", "~> 1.7"

gem "google-protobuf", require: false

gem "active_job-performs", "~> 0.3.1"

gem "ruby-openai"

gem "json-repair", "~> 0.2.0"

gem "redcarpet", "~> 3.6"
gem "country_select"

# admin
gem "avo"
gem "marksmith"
# gem "commonmarker", "~> 2.6"

gem "frozen_record", "~> 0.27.2"
gem "diffy"
gem "discard"

gem "httparty"

# Use OmniAuth to support multi-provider authentication [https://github.com/omniauth/omniauth]
gem "omniauth"
gem "omniauth-github"
# Provides a mitigation against CVE-2015-9284 [https://github.com/cookpad/omniauth-rails_csrf_protection]
gem "omniauth-rails_csrf_protection"

gem "hotwire_combobox", "~> 0.4.0"

gem "rails-i18n", "~> 8.0"

# Ruby standards gems
gem "openssl" # https://github.com/ruby/openssl/issues/949
gem "ostruct"

gem "geocoder"
