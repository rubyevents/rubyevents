# Adding Unpublished Talks to RubyEvents

This guide explains how to add talk information for conferences and events in the RubyEvents platform, including scheduled talks that haven't been recorded yet.

## Overview

Talk data is stored in YAML files within the conference/event directories. Each conference has a videos.yml file that defines all talks, including those that are scheduled, recorded, or pending publication.

## File Structure

Talks are stored in YAML files at:
```
data/{series-name}/{event-name}/videos.yml
```

For example:
- [`/data/ruby-community-conference/ruby-community-conference-winter-edition-2026/videos.yml`](/data/ruby-community-conference/ruby-community-conference-winter-edition-2026/videos.yml)
- [`data/fukuoka-rubykaigi/fukuoka-rubyistkaigi-05/videos.yml`](/data/fukuoka-rubykaigi/fukuoka-rubyistkaigi-05/videos.yml)

## YAML Structure

### Basic Structure

```yaml
---
- id: "unique-talk-id"
  title: "Talk Title"
  raw_title: "Conference Name - Talk Title"
  date: "2025-01-15"
  description: "Description of the talk"
  event_name: "RubyConf 2025"
  published_at: "TODO"
  speakers:
    - Speaker Name
  slug: "talk-title-conference-2025"
  video_provider: "scheduled"
  video_id: "unique-talk-id"
```

### Complete Example

```yaml
---
- id: "matz-keynote-rubyconf-2025"
  title: "Opening Keynote"
  raw_title: "RubyConf 2025 - Opening Keynote"
  date: "2025-04-10"
  description: "The opening keynote for RubyConf 2025."
  event_name: "RubyConf 2025"
  published_at: "2025-05-01"
  announced_at: "2025-01-15"
  speakers:
    - Matz
  slug: "opening-keynote-rubyconf-2025"
  video_provider: "youtube"
  video_id: "dQw4w9WgXcQ"
  kind: "keynote"
  language: "en"
  track: "Main Stage"
  location: "Ballroom A"
  slides_url: "https://speakerdeck.com/example/keynote"
  additional_resources:
    - name: "Blog Post"
      url: "https://example.com/keynote-recap"
      type: "blog"
      title: "Keynote Recap: The Future of Ruby"

- id: "jane-developer-talk-rubyconf-2025"
  title: "Building Better Rails Apps"
  raw_title: "RubyConf 2025 - Building Better Rails Apps"
  date: "2025-04-10"
  description: ""
  event_name: "RubyConf 2025"
  published_at: "TODO"
  speakers:
    - Jane Developer
  slug: "building-better-rails-apps-rubyconf-2025"
  video_provider: "scheduled"
  video_id: "building-better-rails-apps"

- id: "lightning-talks-rubyconf-2025"
  title: "Lightning Talks"
  raw_title: "RubyConf 2025 - Lightning Talks"
  date: "2025-04-11"
  description: "A collection of 5-minute lightning talks."
  event_name: "RubyConf 2025"
  published_at: "TODO"
  speakers: []
  slug: "lightning-talks-rubyconf-2025"
  video_provider: "children"
  video_id: "lightning-talks"
  kind: "lightning"
  talks:
    - id: "lightning-talk-1"
      title: "Quick Tip: Ruby 3.3 Features"
      speakers:
        - Lightning Speaker
      video_provider: "parent"
      video_id: "lightning-talk-1"
      start_cue: "0:00"
      end_cue: "5:00"
```

## Field Descriptions

### Required Fields

| Field | Description |
|-------|-------------|
| `id` | Unique identifier for the video/talk |
| `date` | Date of the talk (YYYY-MM-DD format) |
| `video_provider` | Video hosting provider (see values below) |
| `video_id` | Video ID on the provider platform |

### Common Fields

| Field | Required | Description |
|-------|----------|-------------|
| `title` | No | Title of the talk |
| `raw_title` | No | Original/raw title from the video source |
| `original_title` | No | Original title in native language |
| `description` | No | Description of the talk |
| `slug` | No | URL-friendly slug |
| `kind` | No | Type of video (e.g., "keynote", "lightning") |
| `status` | No | Status of the video |
| `speakers` | No | Array of speaker names |
| `event_name` | No | Name of the event (e.g., "RailsConf 2024") |
| `time` | No | Time of the talk |
| `published_at` | No | Date when the video was published (YYYY-MM-DD format) |
| `announced_at` | No | Date when the talk was announced |
| `location` | No | Location within the venue |
| `track` | No | Conference track (e.g., "Main Stage", "Workshop") |
| `language` | No | Language of the talk |
| `slides_url` | No | URL to the slides |

### Video Provider Values

| Value | Description |
|-------|-------------|
| `youtube` | Video hosted on YouTube |
| `vimeo` | Video hosted on Vimeo |
| `mp4` | Direct MP4 video file |
| `scheduled` | Talk is scheduled but not yet recorded |
| `not_recorded` | Talk was not recorded |
| `not_published` | Video exists but is not yet published |
| `parent` | Sub-talk that uses parent video (for panel discussions) |
| `children` | Parent video containing multiple sub-talks |

### External Player Fields

| Field | Required | Description |
|-------|----------|-------------|
| `external_player` | No | Whether to use external player (boolean) |
| `external_player_url` | No | URL for external player |

### Thumbnail Fields

| Field | Description |
|-------|-------------|
| `thumbnail_xs` | Extra small thumbnail URL |
| `thumbnail_sm` | Small thumbnail URL |
| `thumbnail_md` | Medium thumbnail URL |
| `thumbnail_lg` | Large thumbnail URL |
| `thumbnail_xl` | Extra large thumbnail URL |
| `thumbnail_classes` | CSS classes for thumbnail |

### Additional Resources

Each talk can have additional resources with the following structure:

```yaml
additional_resources:
  - name: "Display Name"
    url: "https://example.com/resource"
    type: "blog"
    title: "Optional Full Title"
```

**Resource Types:**
- `write-up`, `blog`, `article` - Written content
- `source-code`, `code`, `repo`, `github` - Code repositories
- `documentation`, `docs` - Documentation
- `presentation` - Presentation slides
- `video`, `podcast`, `audio` - Media content
- `gem`, `library` - Ruby gems or libraries
- `transcript`, `handout`, `notes` - Supporting materials
- `photos`, `link`, `book` - Other resources

### Sub-Talks (for Panels/Lightning Talks)

For videos containing multiple talks, use the `talks` array:

```yaml
talks:
  - id: "sub-talk-id"
    title: "Sub-talk Title"
    speakers:
      - Speaker Name
    video_provider: "parent"
    video_id: "sub-talk-id"
    start_cue: "10:30"
    end_cue: "25:45"
    thumbnail_cue: "12:00"
```

### Alternative Recordings

For talks with multiple recordings (e.g., different languages):

```yaml
alternative_recordings:
  - title: "Japanese Version"
    language: "ja"
    video_provider: "youtube"
    video_id: "xyz123"
```

## Step-by-Step Guide

### 1. Check for Existing Videos File

First, check if a videos file already exists:

```bash
ls data/{series-name}/{event-name}/videos.yml
```

### 2. Create or Edit the Videos File

If the file doesn't exist, create it:

```bash
mkdir -p data/{series-name}/{event-name}
touch data/{series-name}/{event-name}/videos.yml
```

### 3. Gather Talk Information

For each talk, collect:
- Talk title
- Speaker name(s)
- Date of the talk
- Video URL (if available) or use "scheduled" for upcoming talks
- Description (if available)
- Any additional resources (slides, blog posts, etc.)

### 4. Structure the YAML

Start with the basic structure:

```yaml
---
- id: ""
  title: "Talk Title"
  raw_title: "Conference - Talk Title"
  date: "2025-01-15"
  description: ""
  event_name: "Conference Name 2025"
  published_at: "TODO"
  speakers:
    - Speaker Name
  slug: "talk-title-conference-2025"
  video_provider: "scheduled"
```

#### Talks not in English

For talks not in English, prefer English descriptions and titles if provided by the event.
Otherwise, use the original language for the description.
Translate the title to English, and store the title in its original language in original_title.

```yaml
- id: "name-talk-type-event-name-year"
  title: "Talk title in English"
  original_title: "Talk title in original language"
  date: "2026-02-28"
  description: "Description in original language"
```

### 5. Verify Speakers Exist

Check if the speaker exists in [speakers.yml](/data/speakers.yml).
If they do, no further action is necessary.
If they don't, create a new record for them, and try to include a GitHub handle.
The other fields are nice, but GitHub is how we deduplicate, auth, and populate the profile, so try to populate that one if you can find it.

## Troubleshooting

### Common Issues

- **Invalid YAML syntax**: Check indentation (use spaces, not tabs)
- **Missing required fields**: Ensure `id`, `date`, `video_provider`, and `video_id` are present
- **Invalid video_provider**: Must be one of the allowed values - [scheduled, not_published, not_recorded, youtube, vimeo, mp4, parent, children]
- **Invalid resource type**: Check that `additional_resources` use valid type values
- **Date format**: Use YYYY-MM-DD format for dates

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create or update the videos.yml file in the appropriate directory
4. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
5. Run `bin/lint`
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing talks:
- Open an issue on GitHub
- Check existing videos.yml files for examples (e.g., `data/rubyconfth/rubyconfth-2026/videos.yml`)
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
