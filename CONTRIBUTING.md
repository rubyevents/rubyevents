# Welcome to RubyEvents.org!

Welcome to RubyEvents.org, and thank you for contributing your time and energy to improving the platform.
We're on a mission to index all ruby events and video talks, and we need your help to do it!

A great way to get started is adding new events and content.
We have a page on the deployed site that has up-to-date information with the remaining known TODOs.
Check out the ["Getting Started: Ways to Contribute" page on RubyEvents.org](https://www.rubyevents.org/contributions) and feel free to start working on any of the remaining TODOs.
Any help is greatly appreciated.

All contributors are expected to abide by the [Code of Conduct](/CODE_OF_CONDUCT.md).

## Getting Started

We have tried to make the setup process as simple as possible so that in a few commands you can have the project with real data running locally.

### Devcontainers

In addition to the local development flow described below, we support [devcontainers](https://containers.dev) and [codespaces](https://github.com/features/codespaces).
If you open this project in VS Code and you have the [dev containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) installed, it will prompt you and ask if you want to reopen in a dev container.
This will set up the dev environment for you in docker, and reopen your editor from within the context of the rails container, so you can run commands and work with the project as if it was local.
All file changes will be present locally when you close the container.

- Clone RubyEvents with https, it tends to behave better, and new `gh auth login` commands won't generate new ssh keys.
- If you cannot fetch or push, use `gh auth login` to auth with GitHub.
- After the container is set up, run `bin/dev` in the terminal to start the development server. The application will be forwarded to [localhost:3000](localhost:3000).
- To run system tests, use `HEADLESS=true bin/rails test`. The HEADLESS=true environment variable ensures Chrome runs in headless mode, which is required in the container environment.

If the ruby version is updated, or you start running into issues, feel free to toss and rebuild the container.

### Local Dev Setup

#### Requirements

- Ruby 4.0.0
- Node.js 22.15.1

#### Setup

To install dependencies and prepare the database run:

```
bin/setup
```

This will seed the database with all speakers, meetups, the last 6 months of events, and all future events.

To load all historical data, run:

```
bin/rails db:seed:all
```

### Environment Variables

You can use the `.env.sample` file as a guide for the environment variables required for the project.
However, there are currently no environment variables necessary for simple app exploration.

### Starting the Application

The following command will start Rails, SolidQueue and Vite (for CSS and JS).

```
bin/dev
```

## Linter

The CI performs these checks:

- erblint
- standardrb
- standard (js)
- prettier (yaml)

Before committing your code you can run `bin/lint` to detect and potentially autocorrect lint errors and validate schemas.

To follow Tailwind CSS's recommended order of classes, you can use [Prettier](https://prettier.io/) along with the [prettier-plugin-tailwindcss](https://github.com/tailwindlabs/prettier-plugin-tailwindcss), both of which are included as devDependencies. This formatting is not yet enforced by the CI.

### Typesense (Optional)

The application uses [Typesense](https://typesense.org/) for enhanced search functionality (spotlight search). Typesense is **optional** for local development. The app works without it, falling back to SQLite FTS5 for search.

**Devcontainers / Docker Compose:** Typesense is already included and starts automatically.

**Local development:** Run Typesense with Docker:

```bash
docker compose -f docker-compose.typesense.yml up -d
```

Once running, you can reindex the data:

```bash
bin/rails search:reindex
```

Useful search commands:

```bash
bin/rails search:status       # Show status of all search backends
bin/rails typesense:health    # Check if Typesense is running
bin/rails typesense:stats     # Show Typesense index statistics
bin/rails typesense:reindex   # Full reindex of Typesense collections
bin/rails sqlite_fts:reindex  # Rebuild SQLite FTS indexes
```

#### Environment Variables

Configure Typesense via environment variables in your `.env` file:

**Local development (single node):**

| Variable | Default | Description |
|----------|---------|-------------|
| `TYPESENSE_HOST` | `localhost` | Typesense server host |
| `TYPESENSE_PORT` | `8108` | Typesense server port |
| `TYPESENSE_PROTOCOL` | `http` | Protocol to use |
| `TYPESENSE_API_KEY` | `xyz` | Your Typesense API key |

**Typesense Cloud with Search Delivery Network (SDN):**

| Variable | Default | Description |
|----------|---------|-------------|
| `TYPESENSE_NODES` | - | Comma-separated list of node hosts (e.g., `xxx-1.a1.typesense.net,xxx-2.a1.typesense.net,xxx-3.a1.typesense.net`) |
| `TYPESENSE_NEAREST_NODE` | - | SDN nearest node hostname (e.g., `xxx.a1.typesense.net`) |
| `TYPESENSE_PORT` | `443` | Typesense server port |
| `TYPESENSE_PROTOCOL` | `https` | Protocol to use |
| `TYPESENSE_API_KEY` | - | Your Typesense Admin API key |

**Other options:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SEARCH_INDEX_ON_IMPORT` | `true` | Whether to update search indexes when importing data from YAML files. Set to `false` to skip indexing during imports (useful for bulk imports followed by a full reindex) |

For local development with Docker, the defaults work out of the box. For production with Typesense Cloud, set `TYPESENSE_NODES` and `TYPESENSE_NEAREST_NODE` to enable the SDN configuration.

## Running the Database Seeds

After adding or modifying data, seed the database to see your changes.
If you are running the dev server, Guard will attempt to import for you on modification.
But if you are not running the dev server, or run into issues - use the seeds.

This will seed the last 6 months of conferences, and all future events and meetups.

```bash
bin/rails db:seed
```

This will seed all data and is what we use in production.

```bash
bin/rails db:seed:all
```

Import one event series and all included events.

```bash
bin/rails db:seed:event_series[blue-ridge-ruby]
```

You can also seed one event series with a script.

```bash
rails runner scripts/import_event.rb blue-ridge-ruby
```

Import all events (but not the series or any other data).
This one is good for if you're updating a lot of events at once and backfilling data.

```bash
bin/rails db:seed:event_series[blue-ridge-ruby]
```

Import all speakers. Great for testing profile update changes.

```bash
bin/rails db:seed:speakers
```

### Troubleshooting

If you encounter a ** Process memory map: ** error, close the dev server, run seeds, and restart.

## Running Tests

We use minitest for all our testing.

Run the full test suite with:

```bash
rails test
```

Run just one test using:

```bash
rails test test/models/talk_test.rb
```

Run just one example using:

```bash
rails test test/models/talk_test.rb:6
```

## UI

For the front-end, we use [Vite](https://vite.dev/), [Tailwind CSS](https://tailwindcss.com/) with [Daisyui](https://daisyui.com/) components, [Hotwire](https://hotwired.dev/), and [Stimulus](https://stimulus.hotwired.dev/).

You can find existing RubyEvents components in our [component library](https://www.rubyevents.org/components).

## Contributing new events

Discovering and documenting new Ruby events is an ongoing effort, and a fantastic way to get familiar with the codebase!

All conference data is stored in the `/data` folder with the following structure:

```
data/
├── speakers.yml                    # Global speaker database
├── railsconf/                      # Series folder
│   ├── series.yml                  # Series metadata
│   ├── railsconf-2023/             # Event folder
│   │   ├── event.yml               # Event metadata
│   │   ├── videos.yml              # Talk data
│   │   ├── schedule.yml            # Optional schedule
│   │   ├── sponsors.yml            # Optional sponsors data
│   │   └── venue.yml               # Optional venue
│   └── railsconf-2024/
│       ├── event.yml
│       └── videos.yml
└── rubyconf/
    ├── series.yml
    └── ...
```

A conference series (`series.yml`) describes a series of events.
Each folder represents a different instance of that event, and must contain an `event.yml`.

The schema for each file is located in `/app/schemas`.

If the YouTube videos for an event are available, you can [create events with a script](docs/ADDING_VIDEOS.md).
Otherwise, you can [create the event or event series manually](docs/ADDING_EVENTS.md).

There are additional guides for adding optional information:

- [visual assets](/docs/ADDING_VISUAL_ASSETS.md)
- [videos](/docs/ADDING_VIDEOS.md)
- [schedules](/docs/ADDING_SCHEDULES.md)
- [sponsors](/docs/ADDING_SPONSORS.md)
- [venues](/docs/ADDING_VENUES.md)

If you have questions about contributing events:

- Open an issue on GitHub
- Check existing event files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
