# Contributing Data

This guide provides steps on how to contribute new videos to the platform. If you wish to make a contribution, please submit a Pull Request (PR) with the necessary information detailed below.

> **Note**: For information on adding visual assets (logos, banners, stickers, etc.), see the [Adding Visual Assets Guide](docs/ADDING_VISUAL_ASSETS.md). You can view all event assets at https://rubyevents.org/pages/assets

There are a few scripts available to help you build those data files by scraping the YouTube API. To use them, you must first create a YouTube API Key and add it to your .env file. Here are the guidelines to get a key https://developers.google.com/youtube/registering_an_application

```
YOUTUBE_API_KEY=some_key
```

## Data Structure

All conference data is stored in the `/data` folder with the following structure:

```
data/
├── speakers.yml                    # Global speaker database
├── railsconf/                      # Series folder
│   ├── series.yml                  # Series metadata
│   ├── railsconf-2023/             # Event folder
│   │   ├── event.yml               # Event metadata
│   │   ├── videos.yml              # Talk data
│   │   └── schedule.yml            # Optional schedule
│   └── railsconf-2024/
│       ├── event.yml
│       └── videos.yml
└── rubyconf/
    ├── series.yml
    └── ...
```

## Adding a New Conference Series

### Step 1 - Create the Series

Create a new folder for your series and add a `series.yml` file:

```bash
mkdir -p data/my-conference
```

Create `data/my-conference/series.yml`:

```yaml
---
name: My Conference
website: https://myconference.org/
twitter: myconference
youtube_channel_name: myconference
kind: conference  # conference, meetup, retreat, or hackathon
frequency: yearly # yearly, monthly, quarterly, etc.
language: english
default_country_code: US
youtube_channel_id: ""  # Will be filled by prepare_series.rb
playlist_matcher: ""    # Optional regex to filter playlists
```

Then run this script to fetch the YouTube channel ID:

```bash
rails runner scripts/prepare_series.rb my-conference
```

### Step 2 - Create Events from YouTube Playlists

If your conference videos are organized as YouTube playlists (one playlist per event), run:

```bash
rails runner scripts/create_events.rb my-conference
```

This will create `event.yml` files for each playlist found. The script skips events that already exist.

**Multi-Event Channels**

Some YouTube channels host multiple conferences (e.g., Confreaks hosts both RubyConf and RailsConf). Use `playlist_matcher` in your `series.yml` to filter playlists:

```yaml
# data/railsconf/series.yml
name: RailsConf
youtube_channel_id: UCWnPjmqvljcafA0z2U1fwKQ
playlist_matcher: rails  # Only matches playlists with "rails" in the title
```

### Step 3 - Extract Videos

Once your events are set up, extract the video information:

```bash
# Extract videos for all events in a series
rails runner scripts/extract_videos.rb my-conference

# Or extract videos for a specific event
rails runner scripts/extract_videos.rb my-conference my-conference-2024
```

### Step 4 - Review and Edit

Review the generated files and make any necessary edits:

**event.yml** - Verify:
- Event dates (`start_date`, `end_date`)
- Location
- Description

**videos.yml** - Each video entry must have:
- `speakers`: Array of speaker names (required - videos without speakers won't display)
- `date`: Date the talk was presented in YYYY-MM-DD format (required)

Example video entry:
```yaml
- title: "What Rust can teach us about Ruby"
  event_name: "RubyConf 2025"
  published_at: "2025-10-12"
  description: "A presentation about Rust and Ruby"
  video_provider: youtube
  video_id: "abc123xyz"
  speakers:
    - "Jane Doe"
  date: "2025-10-11"
```

## Custom Video Metadata Parsers

The default `YouTube::VideoMetadata` class tries to extract speaker names from video titles. If this doesn't work well for your conference, you can create a custom parser and specify it in `event.yml`:

```yaml
# data/rubyconf-au/rubyconf-au-2015/event.yml
---
id: PL9_jjLrTYxc2uUcqG2wjZ1ppt-TkFG-gm
title: RubyConf AU 2015
metadata_parser: "YouTube::VideoMetadata::RubyConfAu"
```

## Adding Events Manually

You can also add events manually without using the scripts:

1. Create the event folder: `mkdir -p data/my-conference/my-conference-2024`
2. Create `event.yml` with event metadata
3. Create `videos.yml` with talk data
4. Optionally add `schedule.yml` for the event schedule

## Running the Database Seed

After adding or modifying data, seed the database to see your changes:

```bash
bin/rails db:seed
```
