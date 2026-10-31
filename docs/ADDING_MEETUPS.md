# Adding a Meetup to RubyEvents

This guide explains how meetup groups and their meetups are organised and how to add or update them. For the general process (series, event, assets), start with [ADDING_EVENTS](ADDING_EVENTS.md).

## Meetups vs Conferences

Meetups work like conferences: every meetup is its own event with its own folder, dates, talks and assets. The difference is where the group lives.

|                       | Conference                                         | Meetup                                                                     |
| --------------------- | -------------------------------------------------- | -------------------------------------------------------------------------- |
| **Series**            | The conference series (e.g. RubyConf)              | **The meetup group** (e.g. London Ruby User Group)                         |
| **Event**             | One per edition (`data/rubyconf/rubyconf-2024/`)   | **One per meetup**, named after its series and date (`data/lrug/lrug-2026-01-12/`) |
| **Group information** | n/a                                                | Description, links, location, organizers and sponsors live in the series   |

So a meetup group looks like this:

```
data/lrug/series.yml              # the group: name, description, links, location, timezone, colors
data/lrug/involvements.yml        # the group's organizers, with the period they organized it
data/lrug/sponsors.yml            # the group's sponsors, with the period they sponsored it
data/lrug/cfp.yml                 # the group's always-open call for proposals
data/lrug/lrug-2026-01-12/event.yml    # one meetup
data/lrug/lrug-2026-01-12/videos.yml   # its talks (left out when it had none)
data/lrug/lrug-2026-02-09/event.yml    # the next one
```

The folder name is the meetup's id, unique across all events, and its URL: `https://www.rubyevents.org/events/lrug-2026-01-12`.

## Series configuration (`series.yml`)

Set `kind: "meetup"` and the group's details. The `"name"` will generally be the organizing group, e.g. "Cityname.rb" or "Ruby Cityname", and never ends in "Meetup": the meetups' titles add that.

There is no `frequency` field: how often a group meets ("Meets monthly", "Meets every two months") is worked out from the dates of its meetups.

A group without an upcoming meetup and none in the last 18 months shows as inactive on its own. When you know a group stopped for good, add `ended: true` to its `series.yml`.

```yaml
---
id: "lrug"
name: "London Ruby User Group"
location: "London, United Kingdom"
timezone: "Europe/London"
website: "https://lrug.org"
kind: "meetup"
language: "English"
default_country_code: "UK"
meetup: "https://www.meetup.com/lrug"
description: |-
  LRUG is a London-based community for anyone who is interested in the Ruby programming language.
banner_background: "#FFF7B9"
featured_background: "#FFF7B9"
featured_color: "#c61300"
coordinates:
  latitude: 51.5072178
  longitude: -0.1275862
```

New groups can be created with the series generator:

```bash
bin/rails g series --series lrug --name "London Ruby User Group" --kind meetup \
  --location "London, United Kingdom" --timezone Europe/London --meetup https://www.meetup.com/lrug
```

The group's images (avatar, banner, card, featured, poster) go in `app/assets/images/events/{series}/default/`, and every meetup uses them unless it has images of its own. A group sticker or stamp goes in `app/assets/images/events/{series}/sticker.webp` / `stamp.webp`, and is collected at any of its meetups.

## Meetup file (`event.yml`)

Each meetup is an event with `kind: "meetup"`, in a folder named after its series and date (`{series}-YYYY-MM-DD`), which is also its id. A second meetup on the same day gets a counter: `lrug-2026-01-12-2`.

```yaml
---
id: "lrug-2026-01-12"
title: "LRUG Meetup January 2026"
subtitle: "New Year Lightning Talks"
location: "London, United Kingdom"
timezone: "Europe/London"
kind: "meetup"
description: |-
  Our first meeting of the year, hosted by Example Ltd.
start_date: "2026-01-12"
end_date: "2026-01-12"
start_time: "18:30"
end_time: "20:30"
venue: "Example Ltd, 1 Example Street"
meetup: "https://www.meetup.com/lrug/events/312345678/"
coordinates:
  latitude: 51.5072178
  longitude: -0.1275862
```

Generate one with:

```bash
bin/rails g event --event-series lrug --kind meetup --date 2026-01-12 --meetup "https://www.meetup.com/lrug/events/312345678/"
```

The folder, title, location, timezone and coordinates default to the series.

A meetup's `title` is its group, "Meetup" and month: `"LRUG Meetup January 2026"`, with the day when the group meets more than once that month: `"Austin.rb Meetup October 14, 2025"`. The group is the series' `meetup_name` when its meetups go by another name than the series (`meetup_name: "LRUG"` for the London Ruby User Group), and its `name` otherwise.

A group whose name already says it is a group leaves out "Meetup": a name with "User Group", "Users Group", "Usergroup", "Group", "Brigade", "Grupa", "Workshop" or "Meetup" in it, like `"Helsinki Ruby Brigade May 2026"` or `"North West Ruby User Group November 2026"`. Acronyms still get it (`"RUG::B Meetup November 2026"`), and so does a shortened `meetup_name` (`"Ruby Warsaw Meetup October 2026"` for the Polish Ruby User Group).

What the organizers call a meetup goes in `subtitle`: `"Pubnite"`, `"Ruby Tuesday #12"`, `"SF Ruby Hack Day"`. Pass it to the generator with `--subtitle`. `bin/rails validate:fix` renames a meetup whose title doesn't follow this, and keeps its old wording as the subtitle.

Links to the meetup's page go in their own fields, and you can use any combination of them:

| Field       | Value                                                        |
| ----------- | ------------------------------------------------------------ |
| `meetup`    | The meetup.com event page                                    |
| `luma`      | The Luma event page                                          |
| `kommunity` | The Kommunity event page                                     |
| `website`   | The meetup's page on the group's own website, or anywhere else |

The group's own pages (its meetup.com group, Luma calendar, website) belong in `series.yml`, not in each meetup.

A meetup somewhere else, like an online meetup of an in-person group, sets its own `location` (`"online"` with `coordinates: false` for online meetups). A cancelled meetup gets `status: "cancelled"`.

## Talks (`videos.yml`)

A meetup's `videos.yml` lists its talks like a conference's, one entry per talk:

```yaml
---
- id: "ifat-ribon-chicagoruby-2025-03-05"
  title: "Build or Buy?"
  date: "2025-03-05"
  video_provider: "not_recorded"
  video_id: "ifat-ribon-chicagoruby-2025-03-05"
  description: |-
    A practical talk that tackles the classic developer question.
  speakers:
    - Ifat Ribon
```

A talk's id is its speakers and the meetup, like `ifat-ribon-chicagoruby-2025-03-05`, the same way conference talks are named. A talk without a recording uses its id as its `video_id`. `bin/rails validate:fix` renames a talk that doesn't follow this and keeps its previous id as `old_id`.

Add talks with `bin/rails g talk --event lrug-2026-01-12 --title "..." --speakers "..."`.

When the whole meetup was recorded as one video, each talk carries that video and where it starts and ends in it. There is no entry for the recording itself:

```yaml
---
- id: "ifat-ribon-chicagoruby-2025-03-05"
  title: "Build or Buy?"
  date: "2025-03-05"
  start_cue: "11:40"
  end_cue: "41:30"
  thumbnail_cue: "11:45"
  published_at: "2025-03-10"
  video_provider: "youtube"
  video_id: "tA8Omrq0Px4"
  description: ""
  speakers:
    - Ifat Ribon
```

The talk's thumbnail is cut from the video at `thumbnail_cue` into `app/assets/images/thumbnails/{meetup}/{talk id}.webp` by `bin/rails extract_thumbnails`.

Every talk that shares a video needs a `start_cue` and an `end_cue`. Use `"TODO"` until you know them, which plays the whole video. List the talks in the order they appear in the recording, without overlapping cues, so one talk ends at or before the next one starts. `bin/rails validate:videos` checks this.

A meetup without talks doesn't need a `videos.yml`.

## Organizers and sponsors of the group

`data/{series}/involvements.yml` and `data/{series}/sponsors.yml` describe the whole group. Each person, organisation or sponsor can carry the period it held the role, as `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Leave `to` out while it lasts, and leave both out when you don't know:

```yaml
---
- name: "Organizer"
  users:
    - Murray Steele
    - name: "Jane Doe"
      from: "2018"
      to: "2022-06"
  organisations:
    - name: "Codebar"
      from: "2021-03-01"
```

The group's page lists current and former organizers and sponsors, and each meetup shows the ones active on its date. Roles of a single meetup, like its host or MC, go in that meetup's own `involvements.yml`.

```bash
bin/rails g involvements --event-series lrug --series-level --name Organizer --users "Jane Doe" --from 2018 --to 2022-06
bin/rails g sponsors --event-series lrug --series-level --name "Example Ltd" --website https://example.com --from 2024
bin/rails g cfp --event-series lrug --series-level --link https://lrug.org/speaking
```

## Groups within groups

A series can sit inside another series folder, like the chapters of an organisation or a meetup group of a conference:

```
data/madison-ruby/series.yml                              # the conference
data/madison-ruby/madison-ruby-2024/event.yml
data/madison-ruby/madison-ruby-meetup/series.yml          # its meetup group
data/madison-ruby/madison-ruby-meetup/madison-ruby-meetup-2024-06-04/event.yml
```

Use `bin/rails g series --parent madison-ruby ...` to create one. Series ids stay unique across all of `data/`.

---

For seeding and PR steps, use the same process as in [ADDING_EVENTS](ADDING_EVENTS.md#submission-process) (e.g. `bin/rails db:seed:event_series[<series-slug>]`, `bin/lint`, `bin/dev`).
