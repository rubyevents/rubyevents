# Adding Conference/Meetup Videos to RubyEvents

This guide provides steps on how to contribute new videos to the platform. If you wish to make a contribution, please submit a Pull Request (PR) with the necessary information detailed below.

The videos file represents talks that have happened at the event, whether they were recorded or not.

There are a few scripts available to help you build those data files by scraping the YouTube API. To use them, you must first create a YouTube API Key and add it to your .env file. Here are the guidelines to get a key https://developers.google.com/youtube/registering_an_application

```
YOUTUBE_API_KEY=some_key
```

## Adding a New Conference Series

### Step 1 - Create the Series

If you do not already have an event series, create a new folder for your series and add a `series.yml` file:

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
playlist_matcher: ""    # Optional text to filter playlists
```

Then run this script to fetch the YouTube channel ID:

```bash
bin/rails runner scripts/prepare_series.rb my-conference
```

### Step 2 - Create Events from YouTube Playlists

If your conference videos are organized as YouTube playlists (one playlist per event), run:

```bash
bin/rails runner scripts/create_events.rb my-conference
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
bin/rails runner scripts/extract_videos.rb my-conference

# Or extract videos for a specific event
bin/rails runner scripts/extract_videos.rb my-conference my-conference-2024
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

The default `YouTube::VideoMetadata` class tries to extract speaker names from video titles.
If this doesn't work well for your conference, you can create a custom parser and specify it in `event.yml`:

```yaml
# data/rubyconf-au/rubyconf-au-2015/event.yml
---
id: PL9_jjLrTYxc2uUcqG2wjZ1ppt-TkFG-gm
title: RubyConf AU 2015
metadata_parser: "YouTube::VideoMetadata::RubyConfAu"
```

## Troubleshooting

**'Psych::Parser#_native_parse': (<unknown>): found unknown escape character while parsing a quoted scalar at line 10 column 19 (Psych::SyntaxError)** - something is malformed - run `bin/lint` for a clearer error
**formatter.mjs:29 const isValueString = typeof value.value === 'string'** - make sure your speakers and dates are valid values

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your videos file in the appropriate directory
4. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
5. Run `bin/lint`
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing events:
- Open an issue on GitHub
- Check existing event files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!