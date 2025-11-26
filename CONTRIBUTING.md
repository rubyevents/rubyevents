# Contributing Data

This guide provides steps on how to contribute new videos to the platform. If you wish to make a contribution, please submit a Pull Request (PR) with the necessary information detailed below.

> **Note**: For information on adding visual assets (logos, banners, stickers, etc.), see the [Adding Visual Assets Guide](ADDING_VISUAL_ASSETS.md). You can view all event assets at https://rubyevents.org/pages/assets

There are a few scripts available to help you build those data files by scraping the YouTube API. To use them, you must first create a YouTube API Key and add it to your .env file. Here are the guidelines to get a key https://developers.google.com/youtube/registering_an_application

```
YOUTUBE_API_KEY=some_key
```

## Proposed Workflow

The proposed workflow is to create the data files in the `/data_preparation` folder using the scripts. Once you have validated those files and eventually cleaned a few errors, you can copy them to `/data` and open a PR with that content.

### Step 1 - Prepare the Event Series

Everything starts with an event series. An event series groups related events together (e.g., RailsConf 2020, RailsConf 2021, etc.).

Add the following information to the `data_preparation/event_series.yml` file:

```yml
- name: Railsconf
  website: https://railsconf.org/
  twitter: railsconf
  youtube_channel_name: confreaks
  kind: conference # Choose either 'conference', 'meetup', 'retreat', or 'hackathon'
  frequency: yearly # Specify if it's 'yearly' or 'monthly'; if you need something else, open a PR with this new frequency
  language: english # Default language of the talks from this conference
  default_country_code: AU # default country to be assigned to the associated events
```

Then run this script:

```bash
rails runner scripts/prepare_event_series.rb
```

This will update your `data_preparation/event_series.yml` file with the youtube_channel_id information.

### Step 2 - Create the Events

This workflow assumes the YouTube channel is organized by playlist with 1 event equating to 1 playlist. Run the following script to create the event files:

```
rails runner scripts/create_playlists.rb
```

You will end up with a data structure like this:

```
data/
├── event_series.yml
├── railsconf
│   ├── railsconf-2021
│   │   └── event.yml
│   ├── railsconf-2022
│   │   └── event.yml
```

At this point, go through each `event.yml` file and perform a bit of verification and editing:

- Add missing descriptions.
- Ensure the year is correct.
- Verify the dates and location.

**Multi-Events Channels**

Some YouTube channels will host multiple conferences. For example, RubyCentral hosts Rubyconf and RailsConf. To cope with that, you can specify in the event series a regex to filter the playlists of this channel. The regex is case insensitive.

Here is an example for RailsConf/RubyConf:

```yml
- name: RailsConf
  youtube_channel_name: confreaks
  playlist_matcher: rails # will only select the playlist where there title match rails
  youtube_channel_id: UCWnPjmqvljcafA0z2U1fwKQ
  ...
- name: RubyConf
  youtube_channel_name: confreaks
  playlist_matcher: ruby # will only select the playlist where there title match ruby
  youtube_channel_id: UCWnPjmqvljcafA0z2U1fwKQ
  ...
```

### Step 3 - Create the Videos

Once your events are curated, you can run the next script to extract the video information. It will iterate each event and extract all videos from the associated YouTube playlist.

```bash
rails runner scripts/extract_videos.rb
```

At this point you have this structure:

```
data/
├── event_series.yml
├── railsconf
│   ├── railsconf-2021
│   │   ├── event.yml
│   │   └── videos.yml
│   ├── railsconf-2022
│   │   ├── event.yml
│   │   └── videos.yml
├── speakers.yml
```

Each video entry in the `videos.yml` files must have the following required fields:
- `speakers`: Array of speaker names. Videos without speakers will not be displayed in the app.
- `date`: The date when the talk was presented (in YYYY-MM-DD format). Videos without dates will not be displayed in the app.

Example of a valid video entry:
```yaml
- title: "What Rust can teach us about Ruby"
  event_name: "RubyConf Example 2025"
  published_at: "2025-10-12"
  description: "A presentation about Rust and Ruby"
  video_provider: youtube
  video_id: "abc123xyz"
  speakers:
    - "Jane Doe"
  date: "2025-10-11"
```

To extract a maximum of information from the YouTube metadata, the raw video information is parsed by a class `YouTube::VideoMetadata`. This class will try to extract speakers from the title. This is the default parser but sometimes the speakers are not extracted correctly, you can create a new class and specify it in the `event.yml` file.

```yml
# data/rubyconf-au/rubyconf-au-2015/event.yml
---
id: PL9_jjLrTYxc2uUcqG2wjZ1ppt-TkFG-gm
title: RubyConf AU 2015
description: ""
published_at: "2017-05-20"
channel_id: UCr38SHAvOKMDyX3-8lhvJHA
year: "2015"
videos_count: 21
slug: rubyconf-au-2015
metadata_parser: "YouTube::VideoMetadata::RubyConfAu" # custom parser
```

### Step 4 - move the data

Once the data is prepared you can move it to the main `/data` folder.
