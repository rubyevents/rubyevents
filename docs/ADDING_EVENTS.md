# Adding a new Conference/Meetup to RubyEvents

This guide explains how to add a new event or event series to RubyEvents.

If you are adding an event or event series that already has videos uploaded to YouTube, see the [ADDING_VIDEOS](/docs/ADDING_VIDEOS.md) guide instead.

## Adding a New Conference Series and Event

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
kind: conference # conference, meetup, retreat, or hackathon
frequency: yearly # yearly, monthly, quarterly, etc.
language: english
default_country_code: US
youtube_channel_id: "" # Will be filled by prepare_series.rb
playlist_matcher: "" # Optional text to filter playlists
```

### Step 2 - Create the Event

If you are backfilling an event that has already happened, and has video recordings on YouTube, you can use a script to automatically generate the event and videos file using the steps in [ADDING_VIDEOS](/docs/ADDING_VIDEOS.md).

Otherwise create the event according to the following specification:

Create a new folder for your event instance.

```bash
mkdir -p data/my-conference/my-conference-2025
```

Create `data/my-conference/my-conference-2025/event.yml`:

```yaml
---
id: "my-conference-2025"
title: "My Conference 2025"
kind: "conference"
location: "Earth"
description: "My Conference is a yearly conference held on Earth and features 20 talks from various speakers, including keynotes by Speaker One and Speaker Two."
year: 2026
start_date: "2026-05-30"
end_date: "2026-05-30"
coordinates:
  latitude: 35.36688868108189
  longitude: 136.46675799457
```

The full schema for an event is available in [EventSchema](app/schemas/event_schema.rb).

### Step 3 - Add Visual Assets

Add visual assets (logos, banners, stickers, etc), using the [Adding Visual Assets Guide](docs/ADDING_VISUAL_ASSETS.md).
You can view all event assets at https://rubyevents.org/pages/assets.
We provide scripts to help generate those assets from a logo and background color.

### Step 4 - Add additional information

Once you've added your event, see our other guides on how to add additional information.

- [Adding a Schedule to an Event](docs/ADDING_SCHEDULES.md)
- [Adding Sponsors to an Event](docs/ADDING_SPONSORS.md)
- [Adding Venues to an Event](docs/ADDING_VENUES.md)

## Troubleshooting

### Common Issues

- **Invalid YAML syntax**: Check indentation (use spaces, not tabs)
- **Missing required fields**: Ensure all required properties are present
- **No featured background found**:

  `No featured background found for Blue Ridge Ruby 2026 :  undefined method 'banner_background' for nil. You might have to restart your Rails server.`

  Remove the keys `banner_background`, `featured_background`, `featured_color`, and follow the steps to [add visual assets](docs/ADDING_VISUAL_ASSETS.md).

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your event file in the appropriate directory
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
