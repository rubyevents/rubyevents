# Adding a new Conference/Meetup to RubyEvents

This guide explains how to add a new event or event series to RubyEvents.

If you are adding an event or event series that already has videos uploaded to YouTube, see the [ADDING_VIDEOS](/docs/ADDING_VIDEOS.md) guide instead.

## Adding a New Event

### Step 1 - Create the Series

If this is the first event of the series added to RubyEvents, you'll need to create the series first.

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

Otherwise create the event using a generator:

```bash
bin/rails g event --event-series haggis-ruby --event haggis-ruby-2026 --name "Haggis Ruby 2026"
```

You can create a venue file when the event is created.

```bash
bin/rails g event --event-series tropicalrb --event tropical-on-rails-2027 --name "Tropical on Rails 2027" --venue-name "" --venue-address "R. Olimpíadas, 205 - Vila Olímpia, São Paulo - SP, 04551-000"
```

The full schema for an event is available in [EventSchema](app/schemas/event_schema.rb).

Check the usage instructions using `--help`.

```bash
bin/rails g event --help
```

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

### FAQ
<details><summary>How do I handle events in other languages?</summary>
  We prefer organizer-provided English copy.
  The title in the original language should be added to the aliases.
  If there is a latin-character version of the title or content, we prefer that.
  Never translate titles or other content using automated tooling.
</details>
<details><summary>How do I handle online events?</summary>
Like this!

```yaml
  location: "online"
  coordinates: false
```
</details>
<details><summary>What about meetups?</summary>
  There's some ongoing work to consolidate how meetups and events are stored.
  Unfortunately this guide does not cover meetups at this time.
</details> 
<details><summary>How should I handle a cancelled event?</summary>
  Cancelled events get an attribute of `status: "cancelled"` which will change how they're displayed on the site.
  We include cancelled events on the site so people have a canonical answer for whether or not an event happened and to communicate an upcoming event is cancelled.
  This also allows us to answer questions like, "How many Ruby events were cancelled in 2020?" or track event cancellations over the years.
  If an event was planned, website created, and announced, even if it never made it to the venue or dates stage, we'd like to include it on the site as part of our mission to index all Ruby events.
  However, we defer to the organizer when it comes to questions of how to represent their event, so if the organizer requests we remove a cancelled event from the history, we will.
</details>

## Submission Process

1. Fork the RubyEvents repository.
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md).
3. Create your event file in the appropriate directory.
4. Run `bin/lint`.
5. Run `bin/rails db:seed:event_series[<series-slug>]` to seed just one event series.
6. Run `bin/dev` and review the event on your dev server.
7. Review "todos" panel on the event page to see if any can be resolved.
8. Submit a pull request.

## Need Help?

If you have questions about contributing events:

- Open an issue on GitHub
- Check existing event files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
