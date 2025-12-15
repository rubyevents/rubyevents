# Adding Conference Schedules to RubyEvents

This guide explains how to add venue information for conferences and events in the RubyEvents platform.

## Overview

Venue data is stored in YAML files within the conference/event directories. Each conference can have its own venue file that describes the event venue, hotel information, and any secondary locations.

## File Structure

Schedules are stored in YAML files at:
```
data/{series-name}/{event-name}/venue.yml
```

For example:
- [`data/sfruby/sfruby-2025/venue.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/sfruby/sfruby-2025/venue.yml)
- [`data/railsconf/railsconf-2025/venue.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/railsconf/railsconf-2025/venue.yml)
- [`data/xoruby/xoruby-atlanta-2025/venue.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/xoruby/xoruby-atlanta-2025/venue.yml)

## YAML Structure

### Basic Structure

```yaml
name: "Limelight Theate"
address:
  street: "349 Decatur St. SE Suite L"
  city: "Atlanta"
  region: "GA"
  postal_code: "30312"
  country: "United States"
  country_code: "US"
  display: "349 Decatur St. SE Suite L, Atlanta, GA 30312"
coordinates:
  latitude: 33.75000945024761
  longitude: -84.37730055582303
maps:
  google: "https://maps.app.goo.gl/dBHgXXzjypc2XWNi7"
```

## Field Descriptions

### Base Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Name of the venue |
| `description` | No | Description of the venue |
| `instructions` | No | Instructions for getting to the venue |

### Address Fields

| Field | Required | Description |
|-------|----------|-------------|
| `street` | No | Street address |
| `city` | No | City name |
| `region` | No | State/Province/Region |
| `postal_code` | No | Postal/ZIP code |
| `country` | No | Country name |
| `country_code` | No | ISO country code (e.g., 'US', 'CA') |
| `display` | No | Full formatted address for display |

### Coordinates Fields

| Field | Required | Description |
|-------|----------|-------------|
| `latitude` | Yes* | Latitude coordinate |
| `longitude` | Yes* | Longitude coordinate |

*Required if `coordinates` section is included

### Maps Fields

| Field | Required | Description |
|-------|----------|-------------|
| `google` | No | Google Maps URL |
| `apple` | No | Apple Maps URL |
| `openstreetmap` | No | OpenStreetMap URL |

### Room Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Room name |
| `floor` | No | Floor location |
| `capacity` | No | Room capacity |
| `instructions` | No | Instructions for finding the room |

### Accessibility Fields

| Field | Required | Description |
|-------|----------|-------------|
| `wheelchair` | No | Wheelchair accessible (boolean) |
| `elevators` | No | Elevators available (boolean) |
| `accessible_restrooms` | No | Accessible restrooms available (boolean) |
| `notes` | No | Additional accessibility notes |

### Additional Location Fields

You can add multiple additional locations for afterparties or events at other venues.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Location name |
| `kind` | No | Type of location (e.g., 'After Party') |
| `description` | No | Location description |
| `address` | No | Location address (simple string) |
| `distance` | No | Distance from main venue |
| `url` | No | Location website URL |

**Coordinates and maps links can be added as well - see coordinates and maps fields for format**

### Hotel Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Hotel name |
| `kind` | No | Type of hotel (e.g., 'Speaker Hotel') |
| `description` | No | Hotel description |
| `address` | No | Hotel address |
| `distance` | No | Distance from venue |
| `url` | No | Hotel website URL |

**Coordinates and maps links can be added as well - see coordinates and maps fields for format**

## Step-by-Step Guide

### 1. Check for Existing Venue File

First, check if a venue file already exists:

```bash
ls data/{series-name}/{event}/venue.yml
```

### 2. Create or Edit the Venue File

If the file doesn't exist, create it:

```bash
touch data/{series-name}/{event}/venue.yml
```

### 3. Gather Venue Information

Collect:
- Event venue information
- Event hotel information
- Any additional locations information

### 4. Structure the YAML

Start with the basic structure and add any relevant location information:

```yaml
---
name:
description:
instructions:
address:
  street:
  city:
  region:
  postal_code:
  country:
  country_code:
  display:
coordinates:
  latitude:
  longitude:
maps:
  google:
  apple:
  openstreetmap:
```

**postal_code must be a string, not a number**

### 5. Add Additional Optional Location Details

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
This is an array of additional event locations.
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

### 6. Validate the YAML

Ensure the YAML is properly formatted:

```bash
yarn format:yml
```

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

## Submission Process

1. Fork the RubyEvents repository
2. Create your schedule file in the appropriate directory
3. Test the file loads correctly
4. Submit a pull request

## Need Help?

If you have questions about contributing schedules:
- Open an issue on GitHub
- Check existing schedule files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
