# Adding Conference Schedules to RubyEvents

This guide explains how to add schedule information for conferences and events in the RubyEvents platform.

## Overview

Schedule data is stored in YAML files within the conference/event directories.
Each conference can have its own schedule file that defines the timing structure and tracks for the event.

The schedule works in conjunction with the conference's `videos.yml` file - talks are automatically mapped to empty time slots in chronological order. This means talks in `videos.yml` must be ordered according to their actual presentation sequence to display correctly in the schedule.

For multi-track conferences, each talk in `videos.yml` must have a `track` field that matches one of the track names defined in the schedule.

## File Structure

Schedules are stored in YAML files at:
```
data/{series-name}/{event-name}/schedule.yml
```

For example:
- [`data/rails-world/rails-world-2024/schedule.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/rails-world/rails-world-2024/schedule.yml)
- [`data/rubyconf/rubyconf-2024/schedule.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/rubyconf/rubyconf-2024/schedule.yml)
- [`data/brightonruby/brightonruby-2024/schedule.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/brightonruby/brightonruby-2024/schedule.yml)

## YAML Structure

### Basic Structure

```yaml
# Schedule: https://conference.com/schedule
# Optional: Embed: https://sessionize.com/api/v2/eventid/view/GridSmart

days:
  - name: "Day 1"
    date: "YYYY-MM-DD"
    grid:
      # Time slots for talks/sessions - NO "items" field
      # These are automatically filled from videos.yml in order
      - start_time: "09:00"
        end_time: "09:45"
        slots: 1  # Single talk

      - start_time: "09:45"
        end_time: "10:15"
        slots: 3  # Three parallel talks

      # Time slots for non-talk activities - WITH "items" field
      # These are schedule-only items (no recordings)
      - start_time: "10:15"
        end_time: "10:30"
        slots: 1
        items:
          - Coffee Break

      # Another talk slot - NO "items" field
      - start_time: "10:30"
        end_time: "11:00"
        slots: 1

tracks:
  - name: "Track Name"
    color: "#RRGGBB"
    text_color: "#FFFFFF"  # Optional
```

### Complete Example

```yaml
# Schedule: https://rubyconf.org/schedule/
# Embed: https://sessionize.com/api/v2/3nqsadrc/view/GridSmart?under=True

days:
  - name: "Day 1"
    date: "2024-11-13"
    grid:
      - start_time: "08:30"
        end_time: "10:00"
        slots: 1
        items:
          - Registration & Breakfast

      - start_time: "09:30"
        end_time: "10:30"
        slots: 1
        # Empty slot - maps to actual talks

      - start_time: "10:30"
        end_time: "10:45"
        slots: 1
        items:
          - Break

      - start_time: "10:45"
        end_time: "11:15"
        slots: 4
        # 4 parallel tracks

      - start_time: "12:45"
        end_time: "14:15"
        slots: 1
        items:
          - Lunch

  - name: "Day 2"
    date: "2024-11-14"
    grid:
      - start_time: "10:00"
        end_time: "11:00"
        slots: 1

      - start_time: "18:15"
        end_time: "19:45"
        slots: 1
        items:
          - title: "Closing Party"
            description: "Join us for drinks and networking to close out the conference."

tracks:
  - name: "Main Track"
    color: "#000000"
    text_color: "#ffffff"

  - name: "Technical Track"
    color: "#0066CC"
    text_color: "#ffffff"

  - name: "Community Track"
    color: "#CC6600"
    text_color: "#ffffff"

  - name: "Lightning Talks"
    color: "#95BF47"
    text_color: "#ffffff"
```

## Field Descriptions

### Day Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Human-readable day name (e.g., "Day 1", "Day 2", "Hack Day") |
| `date` | Yes | Date in ISO format (YYYY-MM-DD) |
| `grid` | Yes | Array of time slots for the day |

### Time Slot Fields

| Field | Required | Description |
|-------|----------|-------------|
| `start_time` | Yes | Start time in 24-hour format (HH:MM) |
| `end_time` | Yes | End time in 24-hour format (HH:MM) |
| `slots` | Yes | Number of parallel tracks/sessions (1 for single track, 2+ for multiple) |
| `items` | No | Array of non-talk activities for this time slot (breaks, meals, registration, social events). These are schedule-only items without recordings. Empty slots are filled with talks from `videos.yml` in running order |

### Track Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name of the track (e.g., "Main Track", "Lightning Talks"). Must match the `track` field in `videos.yml` for talks in this track |
| `color` | Yes | Hex color code for the track (e.g., "#FF0000") |
| `text_color` | No | Text color for contrast (defaults to white "#FFFFFF") |

### Item Fields

Items can be simple strings or objects with additional details:

| Field | Required | Description |
|-------|----------|-------------|
| `title` | No | Title of the activity (when using object format) |
| `description` | No | Detailed description of the activity |

## Common Schedule Elements

### Standard Activities

Typical schedule-only items (activities without recordings, simple string format):
- `Registration` - Check-in and badge pickup
- `Break` - General breaks between sessions
- `Coffee Break` - Coffee and networking time
- `Lunch` - Meal break
- `Breakfast` - Morning refreshments
- `Opening` - Conference opening remarks (when not recorded)
- `Closing` - Conference wrap-up (when not recorded)
- `Welcome` - Welcome reception or gathering

### Special Events

For non-talk events with additional details (object format). These are schedule-only activities without individual talk recordings:

```yaml
items:
  - title: "Opening Reception"
    description: "Welcome drinks and networking before the conference begins."

  - title: "Sponsor Showcase"
    description: "Meet our sponsors and learn about their products and services."

  - title: "Panel Discussion"
    description: "Community panel discussion (when not recorded as individual talks)."

  - title: "Networking Hour"
    description: "Structured networking time for attendees."
```

## Track Configuration

### Common Track Types

1. **Main/Keynote Track** - Primary presentations and keynotes
2. **Technical Track** - Deep technical sessions
3. **Community Track** - Community-focused presentations
4. **Lightning Talks** - Short presentation format
5. **Workshop Track** - Hands-on learning sessions
6. **Beginner Track** - Introductory content

### Schedules in other Languages

We prefer the English translation of the schedule if provided, otherwise use the content provided by the organizers.

### Track Colors

Choose colors that provide good contrast and visual distinction:

```yaml
tracks:
  - name: "Main Stage"
    color: "#000000"     # Black
    text_color: "#ffffff"

  - name: "Technical Track"
    color: "#0066CC"     # Blue
    text_color: "#ffffff"

  - name: "Community Track"
    color: "#CC6600"     # Orange

  - name: "Lightning Talks"
    color: "#95BF47"     # Green

  - name: "Workshop Track"
    color: "#9900CC"     # Purple
```

## Step-by-Step Guide

### 1. Check for Existing Schedule File

First, check if a schedule file already exists:

```bash
ls data/{series-name}/{event}/schedule.yml
```

### 2. Create or Edit the Schedule File

If the file doesn't exist, create it:

```bash
touch data/{series-name}/{event}/schedule.yml
```

### 3. Gather Schedule Information

For each day, collect:
- Official conference dates
- Start and end times for each session
- Break and meal times
- Number of parallel tracks
- Track names and any color preferences
- Special events or activities

### 4. Structure the YAML

Start with the basic structure and add days in chronological order:

```yaml
# Schedule: [source URL]

days:
  - name: "Day 1"
    date: "YYYY-MM-DD"
    grid: []

tracks: []
```

### 5. Add Time Slots

Fill in the time slots for each day. Remember:
- Use 24-hour format (e.g., "14:30")
- Include leading zeros (e.g., "09:00")
- Empty slots (no `items`) automatically map to talks from `videos.yml`
- Slots with `items` are schedule-only activities (breaks, meals, networking, etc.) without individual recordings

**Important**: Empty time slots are filled with talks from the conference's `videos.yml` file in running order. The talks must be ordered chronologically in the `videos.yml` file to match the schedule grid timing.

### 6. Configure Tracks

If the conference has multiple tracks, define them. **Important**: Track names must exactly match the `track` field values used in the conference's `videos.yml` file:

```yaml
tracks:
  - name: "Main Track"      # Must match track: "Main Track" in videos.yml
    color: "#000000"

  - name: "Lightning Talks"  # Must match track: "Lightning Talks" in videos.yml
    color: "#95BF47"
```

### 7. Validate the YAML

Ensure the YAML is properly formatted:

```bash
yarn format:yml
```

## Finding Schedule Information

### Official Sources
1. **Conference website**: Look for "Schedule", "Agenda", or "Program" pages
2. **Event platforms**: Check Sessionize, Eventbrite, or Luma event pages
3. **Mobile apps**: Conference-specific mobile applications
4. **Social media**: Official conference accounts may post schedules

### Third-party Sources
- Attendee blog posts with schedule screenshots
- Video recordings showing schedule information
- Conference programs (PDF downloads)
- Archive sites (Wayback Machine) for past events

## Time Format Guidelines

- **Format**: Use 24-hour format (e.g., "14:30", not "2:30 PM")
- **Leading zeros**: Include for single-digit hours (e.g., "09:00")
- **Precision**: Most conferences use 15 or 30-minute intervals
- **Lightning talks**: Can use precise times like "15:36" for short presentations
- **Time zone**: Use conference local time consistently

## Troubleshooting

### Common Issues

- **Invalid YAML syntax**: Check indentation (use spaces, not tabs)
- **Missing required fields**: Ensure all required properties are present
- **Time conflicts**: Verify start/end times don't overlap incorrectly
- **Track mismatch**: Number of tracks should match maximum `slots` used
- **Track name mismatch**: Track names in `schedule.yml` must exactly match `track` field values in `videos.yml`
- **Talk order mismatch**: If talks appear in wrong schedule slots, check that `videos.yml` has talks in chronological order

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your schedule file in the appropriate directory
4. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
5. Run `bin/lint`
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing schedules:
- Open an issue on GitHub
- Check existing schedule files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
