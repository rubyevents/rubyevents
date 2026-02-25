# Adding Conference Venues to RubyEvents

This guide explains how to add venue information for conferences and events in the RubyEvents platform.

## Overview

Venue data is stored in YAML files within the conference/event directories.
Each conference can have its own venue file that describes the event venue, hotel information, and any secondary locations.

## File Structure

Venues are stored in YAML files at:

```
data/{series-name}/{event-name}/venue.yml
```

For example:

- [`data/sfruby/sfruby-2025/venue.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/sfruby/sfruby-2025/venue.yml)
- [`data/railsconf/railsconf-2025/venue.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/railsconf/railsconf-2025/venue.yml)
- [`data/xoruby/xoruby-atlanta-2025/venue.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/xoruby/xoruby-atlanta-2025/venue.yml)

All permitted fields are defined in [VenueSchema.](/app/schemas/venue_schema.rb)

## Generation

Generate a venue.yml using the [VenueGenerator](/lib/generators/venue/venue_generator.rb)!

```bash
bin/rails g venue --event-series=tiny-ruby-conf --event=tiny-ruby-conf-2026 --name="Korjaamo Kino cinema" --address "Töölönkatu 51 A-B, 00250 Helsinki"
```

> [!IMPORTANT]
> The generator uses Geolocator to geocode the address, and fetch coordinates.
> For more accurate results, set your GEOLOCATE_API_KEY in [.env](/.env) to a google api key.
> Otherwise nominatim and open street map will be used for geolocation.

There are multiple optional sections in the venue information, including locations, hotels, rooms, spaces, accessbility, and nearby.

To include or exclude these sections, pass flags to the generator.

This includes all sections:

```bash
bin/rails g venue --event-series=tiny-ruby-conf --event=tiny-ruby-conf-2026 --name="Korjaamo Kino cinema" --address "Töölönkatu 51 A-B, 00250 Helsinki" --accessbility --hotels --nearby --locations --rooms --spaces
```

This includes only primary venue information:

```bash
bin/rails g venue --event-series=tiny-ruby-conf --event=tiny-ruby-conf-2026 --name="Korjaamo Kino cinema" --address "Töölönkatu 51 A-B, 00250 Helsinki" --no-accessbility --no-hotels --no-nearby --no-locations --no-rooms --no-spaces
```

Check the usage instructions using `--help`.

```bash
bin/rails g venue --help
```

## Step-by-Step Guide

### 1. Check for Existing Venue File

First, check if a venue file already exists:

```bash
ls data/{series-name}/{event}/venue.yml
```

### 2. Create or Edit the Venue File

If the file doesn't exist, create it:

```bash
bin/rails g venue --event-series=tiny-ruby-conf --event=tiny-ruby-conf-2026 --name="Korjaamo Kino cinema" --address "Töölönkatu 51 A-B, 00250 Helsinki"
```

### 3. Gather Venue Information

Collect:

- Event venue information
- Event hotel information
- Any additional locations information

### 4. Structure the YAML

Fill in the template with all relevant information, delete any extraneous fields.

### 5. Add Optional Location Details

#### Accessibility information

```yaml
accessibility:
  wheelchair:
  elevators:
  accessible_restrooms:
  notes:
```

#### Nearby location details from the event organizers

```yaml
nearby:
  public_transport:
  parking:
```

#### Meeting rooms in the venue

```yaml
rooms:
  - name:
    floor:
    capacity:
    instructions:
```

#### Spaces in the venue

```yaml
spaces:
  - name:
    floor:
    instructions:
```

#### Additional Locations

This is an array of additional event locations such as afterparties or secondary venues.

```yaml
locations:
  - name:
    kind:
    description:
    address:
    distance:
    url:
    coordinates:
      latitude:
      longitude:
    maps:
      google:
      apple:
```

#### Hotel information

```yaml
hotels:
  - name:
    kind:
    description:
    address:
    url:
    distance:
    coordinates:
      latitude:
      longitude:
    maps:
      google:
      apple:
```

### 6. Format your yaml

Run the linter to automatically format and verify all required properties are present.

```bash
bin/lint
```

### 5. Run seeds to load data

Run the event series seed to load data.

```bash
bundle exec rake db:seed:event_series[event-series-slug]
```

### 6. Review on your dev server

Start the dev server and review the event.

```bash
bin/dev
```

> [!IMPORTANT]
> Verify the address is correct in the venue map, and all links go to the correct venue.

## Finding Schedule Information

### Official Sources

1. **Conference website**: Look for "Venue" or "About" pages
2. **Event platforms**: Check Sessionize, Eventbrite, or Luma event pages
3. **Mobile apps**: Conference-specific mobile applications
4. **Social media**: Official conference accounts may post venue

### Third-party Sources

- Attendee blog posts with venue information
- Video recordings showing venue information
- Conference programs (PDF downloads)
- Archive sites (Wayback Machine) for past events

## Troubleshooting

### Common Issues

- **Invalid YAML syntax**: Check indentation (use spaces, not tabs)
- **Missing required fields**: Ensure all required properties are present
- **Stringify postal_code**: postal_code must be a string
- **No newlines in address**: Ensure there are no newlines in the address

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your venue file in the appropriate directory
4. Run `bin/lint`
5. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing venues:

- Open an issue on GitHub
- Check existing venue files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
