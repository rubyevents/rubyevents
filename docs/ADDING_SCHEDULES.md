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

The [ScheduleSchema](app/schemas/schedule_schema.rb) defines all valid attributes.

## Generating a schedule

Use the generator to build a basic schedule with talks, breakfast, lunch, and closing party.

```bash
bin/rails g schedule --event-series rbqconf --event rbqconf-2026 --break_duration 5
```

The generator will pull information from the event about days and how many talks need to be scheduled and try to schedule accordingly.

Get help on usage by calling help on the generator.

```bash
bin/rails g schedule --help
```

## Customising the file

Schedules are different for every event.
This generator will give you a basic schedule with registration, lunch, and talks, but we expect that it will need to be customized by hand.
If you have a workshop track, you'll definitely need to customize the final yml.

```
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

```

### 3. Gather Schedule Information

For each day, collect:
- Official conference dates
- Start and end times for each session
- Break and meal times
- Number of parallel tracks
- Track names and any color preferences
- Special events or activities

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
