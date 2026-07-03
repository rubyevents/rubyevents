# Adding a Meetup to RubyEvents

This guide explains how meetups differ from conferences and how to add or update meetup data. For the general process (series, event, assets), start with [ADDING_EVENTS](ADDING_EVENTS.md).

## Meetups vs Conferences

|                 | Conference                                                         | Meetup                                                                                                                        |
| --------------- | ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| **Event model** | One Event per edition (e.g. RubyConf 2024, RubyConf 2025)          | **One Event per meetup** (e.g. "ChicagoRuby Meetup")                                                                          |
| **Editions**    | Each edition has its own folder and `event.yml`                    | Each **monthly (or periodic) edition is a single entry in `videos.yml`**                                                      |
| **Videos**      | One `videos.yml` per event edition; each talk is usually one video | One `videos.yml` for the whole meetup; **each entry = one edition** (one meetup night), even if that edition had no recording |

So for a meetup you have:

- **One** `data/{series-slug}/{event-slug}/event.yml` — describes the meetup itself (name, location, website).
- **One** `data/{series-slug}/{event-slug}/videos.yml` — list of **editions**. Each item is one meetup night (e.g. "March 2024"); it may have no video, one long video (with cues), or multiple child videos.

## Series configuration

In `data/{series-slug}/series.yml`, set `kind: "meetup"` and typically `frequency: "monthly"`:

```yaml
---
name: "Amsterdam.rb"
website: "https://www.amsrb.org"
kind: "meetup"
frequency: "monthly"
default_country_code: "NL"
language: "english"
youtube_channel_id: "UCyExf-593j4hjN_cFCSnr2w"
```

The `"name"` will generally be the organizing group, e.g. Cityname.rb or "Ruby Cityname".

## Event file (`event.yml`)

The meetup **event** is a single, ongoing group — one `event.yml` per meetup. Required fields and conventions are the same as in [ADDING_EVENTS](ADDING_EVENTS.md); `kind` should be `"meetup"`. You don't need start and end dates.

**Example:** `data/chicagoruby/chicagoruby/event.yml`

```yaml
---
id: "chicagoruby-meetup"
title: "ChicagoRuby Meetup"
kind: "meetup"
location: "Chicago, IL, United States"
description: |-
  ChicagoRuby is a group of developers & designers who use Ruby, Rails, and related tech.
banner_background: "#FFFFFF"
featured_background: "#FFFFFF"
featured_color: "#D0232B"
website: "https://chicagoruby.org"
coordinates:
  latitude: 41.88325
  longitude: -87.6323879
```

More examples: [Amsterdam.rb](https://github.com/rubyevents/rubyevents/blob/main/data/amsterdam-rb/amsterdam-rb-meetup/event.yml), [SF Bay Area Ruby](https://github.com/rubyevents/rubyevents/blob/main/data/sf-bay-area-ruby/sf-bay-area-ruby-meetup/event.yml), [Geneva.rb](https://github.com/rubyevents/rubyevents/blob/main/data/geneva-rb/geneva-rb-meetup/event.yml), [Barcelona.rb](https://github.com/rubyevents/rubyevents/blob/main/data/barcelona-rb/barcelona-rb-meetup/event.yml).

---

## Structuring `videos.yml` for meetups

Each **entry** in `videos.yml` is **one edition** of the meetup (one evening/month). The `date` is the meetup date. Depending on how that edition was recorded, use one of the patterns below.

### 1. No video for that meetup edition

The edition happened but nothing was recorded (or you only have a schedule). Still add one entry so the edition appears on the site; use `video_provider: "children"` and list talks with `video_provider: "not_recorded"`.

**Real example:** Geneva.rb October 2023 — one edition, one talk, no recording.

**File:** `data/geneva-rb/geneva-rb-meetup/videos.yml` (excerpt)

```yaml
- id: "geneva-rb-october-2023"
  title: "Geneva.rb October 2023"
  event_name: "Geneva.rb October 2023"
  date: "2023-10-30"
  video_provider: "children"
  video_id: "geneva-rb-october-2023"
  description: |-
    This first meeting will be fairly informal. We'll do an initial round of introductions.
    Yannis will then give a short presentation of a new feature of Ruby 3.2: The Data class.
    https://www.meetup.com/geneva-rb/events/295865704
  talks:
    - title: "New Feature of Ruby 3.2: The Data class"
      event_name: "Geneva.rb October 2023"
      date: "2023-10-03"
      speakers:
        - Yannis Jaquet
      id: "yannis-jaquet-geneva-rb-october-2023"
      video_id: "yannis-jaquet-geneva-rb-october-2023"
      video_provider: "not_recorded"
      description: |-
        Yannis will then give a short presentation of a new feature of Ruby 3.2: The Data class.
```

If the edition had no talks at all, you can still add a single entry with `video_provider: "not_recorded"`, a unique `id` and `video_id`, and an optional `description`; `talks` can be omitted or empty.

---

### 2. One long video for the meetup (cue points)

The whole edition is one YouTube (or other) video; each “talk” is a segment with `start_cue` and `end_cue`. Use `video_provider: "youtube"` (or the real provider) on the edition and `video_provider: "parent"` on each talk.

**Real example:** ChicagoRuby Meetup March 2025 — one YouTube video, multiple segments.

**File:** `data/chicagoruby/chicagoruby/videos.yml` (excerpt)

```yaml
- id: "chicagoruby-meetup-march-2025-chicagoruby"
  title: "ChicagoRuby Meetup - March 2025"
  raw_title: "ChicagoRuby Meetup at Adler Planetarium (March, 2025)"
  event_name: "ChicagoRuby Meetup - March 2025"
  date: "2025-03-05"
  published_at: "2025-05-22"
  description: |-
    Save the date! On March 5th we'll have the Ruby meetup at Adler Planetarium.
    Speaker: Ifat Ribon
    Speaker: Noel Rappin - "Does Ruby Love Me Back? What Developer Happiness Means in Ruby"
    https://www.meetup.com/chicagoruby/events/305503069
  video_provider: "youtube"
  video_id: "tA8Omrq0Px4"
  talks:
    - title: "Intro"
      date: "2025-03-05"
      start_cue: "00:00"
      end_cue: "11:40"
      id: "michelle-yuen-chicagoruby-meetup-march-2025"
      video_id: "michelle-yuen-chicagoruby-meetup-march-2025"
      video_provider: "parent"
      event_name: "ChicagoRuby Meetup - March 2025"
      speakers:
        - Michelle Yuen

    - title: "Build or Buy?"
      date: "2025-03-05"
      start_cue: "11:40"
      end_cue: "41:30"
      id: "ifat-ribon-chicagoruby-meetup-march-2025"
      video_id: "ifat-ribon-chicagoruby-meetup-march-2025"
      video_provider: "parent"
      event_name: "ChicagoRuby Meetup - March 2025"
      description: |-
        A practical talk that tackles the classic developer question: Should you build it yourself, use a gem, or go with an existing SaaS solution?
      speakers:
        - Ifat Ribon

    - title: "Does Ruby Love Me Back?"
      date: "2025-03-05"
      start_cue: "48:37"
      end_cue: "1:23:00"
      thumbnail_cue: "50:01"
      id: "noel-rappin-chicagoruby-meetup-march-2025"
      video_id: "noel-rappin-chicagoruby-meetup-march-2025"
      video_provider: "parent"
      event_name: "ChicagoRuby Meetup - March 2025"
      description: |-
        A nostalgic and insightful journey into what makes Ruby uniquely expressive and joyful.
      speakers:
        - Noel Rappin
```

Cue format: use timestamps like `"04:30"`, `"1:15:45"`, or `"00:00:12"` (HH:MM:SS). Each talk’s `end_cue` should match the next talk’s `start_cue` (or the end of the stream).

---

### 3. Multiple separate videos (one per talk)

The edition has several talks, each on its own YouTube (or other) video. Use `video_provider: "children"` on the edition and give each talk its own `video_provider: "youtube"` (or other) and `video_id`.

**Real example:** Amsterdam.rb December 2019 — one edition, two separate videos.

**File:** `data/amsterdam-rb/amsterdam-rb-meetup/videos.yml` (excerpt)

```yaml
- id: "amsterdam-rb-2019-12"
  title: "Amsterdam.rb Meetup December 2019"
  raw_title: "Amsterdam.rb Meetup December 2019 - OPSDEV - Pieter Lange"
  date: "2019-12-17"
  event_name: "Amsterdam.rb Meetup December 2019"
  published_at: "2019-12-17"
  video_provider: "children"
  video_id: "amsterdam-rb-2019-12"
  description: ""
  talks:
    - title: "How Ruby devs can make the lives of their ops people easier / better / more enjoyable"
      raw_title: "Amsterdam.rb Meetup December 2019 - OPSDEV - Pieter Lange"
      date: "2019-12-17"
      event_name: "Amsterdam.rb Meetup December 2019"
      published_at: "2019-12-17"
      video_provider: "youtube"
      id: "pieter-lange-amsterdamrb-meetup-december-2019"
      video_id: "NgSFh_hGQVk"
      speakers:
        - Pieter Lange
      description: |-
        Live stream of the Amsterdam.rb Meetup of the 17th of December.
        Talk 1: Pieter Lange on how Ruby devs can make the lives of their ops people easier.

    - title: "The Hippocratic license"
      raw_title: "Amsterdam.rb Meetup December 2019 - Hippocratic license - Noah Berman"
      date: "2019-12-17"
      event_name: "Amsterdam.rb Meetup December 2019"
      published_at: "2019-12-17"
      video_provider: "youtube"
      id: "noah-berman-amsterdamrb-meetup-december-2019"
      video_id: "Yg9LapGCP4I"
      speakers:
        - Noah Berman
      description: |-
        Noah Berman on the Hippocratic license, how it came about, what it means, what one should consider.
```

Summary of `video_provider` for meetup editions:

| Situation                 | Edition `video_provider`     | Talk `video_provider`                 |
| ------------------------- | ---------------------------- | ------------------------------------- |
| No recording              | `children`                   | `not_recorded` (or omit talks)        |
| One long video (cues)     | `youtube` (or real provider) | `parent`                              |
| Multiple videos           | `children`                   | `youtube` (or real provider) per talk |
| Planned, not yet recorded | `children`                   | `scheduled`                           |

---

For seeding and PR steps, use the same process as in [ADDING_EVENTS](ADDING_EVENTS.md#submission-process) (e.g. `bin/rails db:seed:event_series[<series-slug>]`, `bin/lint`, `bin/dev`).
