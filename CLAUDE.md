# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
