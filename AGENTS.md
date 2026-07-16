# AGENTS.md

This file provides guidance to coding agents (Claude Code, Cursor, Codex, etc.) when working with code in this repository.

## Common Development Commands

### Setup & Development

- `bin/setup` - Full setup including database seeding via docker-compose
- `bin/dev` - Start Rails server, SolidQueue jobs, and Vite (for CSS/JS)
- `bin/lint` - Run all formatters and linters (StandardRB, JS Standard, ERB lint, yerba)
- `bin/rails db:seed` - Seed database with conference data manually
- `bin/rails db:seed:all` - Seed database with all conference data manually

### Testing

- `bin/rails test` - Run the full test suite (uses Minitest)
- `bin/rails test test/system/` - Run system tests
- `bin/rails test test/models/speaker_test.rb` - Run specific test file

### Linting & Formatting

- `bundle exec standardrb --fix` - Fix Ruby formatting issues
- `yarn format` - Fix JavaScript formatting
- `bundle exec erb_lint --lint-all --autocorrect` - Fix ERB templates
- `yarn herb:lint` - Lint ERB templates with the Herb linter
- `bundle exec yerba apply` - Format YAML files in data/ (uses Yerbafile rules)
- `bundle exec yerba check` - Validate YAML files match Yerbafile rules (used in CI)

### Yerba (YAML Formatting)

This project uses [yerba](https://github.com/marcoroth/yerba) to enforce consistent YAML formatting across all data files. The `Yerbafile` in the project root defines formatting rules as pipelines.

Key commands:
- `bundle exec yerba apply` - Apply all Yerbafile rules and write changes
- `bundle exec yerba check` - Verify all files match rules (exits 1 if not, used in CI)
- `bundle exec yerba get <file> <selector>` - Read values from YAML files
- `bundle exec yerba set <file> <selector> <value>` - Update values in YAML files
- `bundle exec yerba selectors <file>` - Show all valid selectors for a file
- `bundle exec yerba sort <file> --by <field> --order <direction>` - Sort or reorder items
- `bundle exec yerba insert <file> <selector> <value>` - Insert new items

Yerba preserves comments, blank lines, quote styles, and formatting. It operates on the concrete syntax tree (CST), so edits are surgical. When editing YAML data files in bulk, yerba is the preferred tool — it's fast, accurate, and supports glob patterns to operate across hundreds of files at once. Prefer yerba commands over manual edits or Ruby scripts when making bulk changes to the data files.

Run `yerba --help` for a full overview of all commands, selectors, conditions, and the Yerbafile. Each subcommand also has detailed help with examples — for instance `yerba get --help`, `yerba sort --help`, or `yerba quote-style --help`.

### Jobs & Search

- `bin/jobs` - Start SolidQueue job worker
- Search reindexing happens automatically in test setup

## Architecture Overview

### Core Models & Relationships

- **Event**: Ruby conferences/meetups (belongs_to EventSeries)
- **Talk**: Conference presentations (belongs_to Event, has_many SpeakerTalks)
- **Speaker**: Presenters (has_many SpeakerTalks, has social media fields)
- **EventSeries**: Conference series/organizers (has_many Events)
- **Topic**: AI-extracted talk topics (has_many TalkTopics)
- **WatchList**: User-curated lists (belongs_to User, has_many WatchListTalks)

### Data Structure

Conference data is stored in YAML files under `/data/`:

- `data/speakers.yml` - Global speaker database
- `data/{series-slug}/series.yml` - Event series metadata (conference organizers/series)
- `data/{series-slug}/{event-name}/event.yml` - Event metadata (dates, location, colors, etc.)
- `data/{series-slug}/{event-name}/videos.yml` - Individual talk data
- `data/{series-slug}/{event-name}/schedule.yml` - Event schedules

### Technology Stack

- **Backend**: Rails 8.0, SQLite, Solid Queue, Solid Cache
- **Frontend**: Vite, Tailwind CSS, daisyUI, Stimulus
- **Admin**: Avo admin panel at `/admin`
- **Authentication**: Custom session-based auth with GitHub OAuth
- **Deployment**: Kamal on Hetzner VPS

### Key Components

- **View Components**: Located in `app/components/`, follows ViewComponent pattern
- **Clients**: API clients for YouTube, GitHub, BlueSky in `app/clients/`
- **Search**: Full-text search for Talks and Speakers using Sqlite virtual tables
- **Jobs**: Background processing for video statistics, transcripts, AI summarization
- **Analytics**: Page view tracking with Ahoy
- **Monitoring**: AppSignal for errors/performance, Mission Control for job monitoring
- **AI Prompts**: Stored in `app/models/prompts/`

### Code Conventions

**Models:**

- Shared behavior lives in concerns: `Suggestable`, `Sluggable`, `Rollupable`, `Searchable`, `Watchable`
- Slugs via `configure_slug(attribute: :title, auto_suffix_on_collision: true)`
- Associated Objects pattern using the `active_record-associated_object` gem
- Model annotations via `annotaterb`
- Counter caches (`counter_cache: :talks_count`), `inverse_of`, and scoped associations
- Normalize data with `normalizes`; encrypt sensitive fields (`encrypts :email, deterministic: true`)
- Use Rails `enum` for status/kind fields

**Controllers:**

- `ApplicationController` includes `Authenticable` (session auth), `Metadata` (SEO tags), and `Analytics` (page tracking)
- Use `skip_before_action :authenticate_user!` for public pages
- Access the current user via `Current.user`
- Pagination with the `pagy` gem
- Keep controllers slim — business logic belongs in models/services

**ViewComponents:**

- All components inherit from `ApplicationComponent` (Dry::Initializer params, `attributes` handling, `display` option)
- UI components live in the `Ui::` namespace under `app/components/ui/`
- Use the `viewcomponents` skill when creating or modifying UI components — it documents the full conventions (mapping constants, `component_classes`, Stimulus integration, testing)

**Frontend:**

- Stimulus controllers in `app/javascript/controllers/` with kebab-case names
- Tailwind CSS + daisyUI, utility-first, CSS variables for theming
- Images in `app/assets/images/`, prefer WebP

**Formatting & Linting:**

- Ruby is formatted with `standardrb` (never rubocop directly)
- JavaScript with `yarn format` (JS Standard)
- ERB templates with `bundle exec erb_lint --lint-all --autocorrect`, plus `yarn herb:lint` for Herb linting (the project uses [Herb](https://herb-tools.dev) as its ERB engine)
- YAML data files with `bundle exec yerba apply` — see the Yerba section above; prefer yerba commands over manual edits for `data/` files
- `bin/lint` runs the whole suite (yerba, data validation, standardrb, JS, erb_lint)

### Authentication & Authorization

- Custom `Authenticator` module provides role-based route constraints
- Admin access required for Avo admin panel and Mission Control Jobs
- GitHub OAuth integration for user registration
- Session-based authentication (not JWT)

### Notable Conventions

- Uses slug-based routing for SEO-friendly URLs
- Talks support multiple video providers (YouTube, Vimeo, etc.)
- AI-powered features: transcript enhancement, topic extraction, summarization
- Responsive design with mobile-first approach
- Canonical references to deduplicate speakers/events/topics

### Testing Setup

- Uses Minitest (not RSpec)
- VCR for API mocking
- Parallel test execution
- Search indexes are reset in test setup
- System tests use Capybara with Selenium

### Data Import Flow

1. YAML files define conference structure
2. Rake tasks process video metadata
3. Background jobs fetch additional data (transcripts, statistics)
4. AI services enhance content (summaries, topics)
