---
name: youtube-videos
description: Use when the user provides a YouTube playlist link/ID or YouTube video links/IDs and wants those recordings added to an event videos.yml file.
allowed-tools: event_talks event_lookup youtube_videos speaker_lookup
---

# Adding YouTube Videos to `videos.yml`

Use this skill when the user gives you:

- a YouTube playlist URL or playlist ID, or
- one or more YouTube video URLs or video IDs,

and wants those recordings added to `data/{series-slug}/{event-slug}/videos.yml`.

## Important Notes

- Review `docs/ADDING_VIDEOS.md` before editing.
- If you need unpublished or scheduled talks instead of published recordings, switch to `docs/ADDING_UNPUBLISHED_TALKS.md`.
- `videos.yml` entries with `video_provider: "youtube"` must end with real values for:
  - `date`
  - `published_at`
  - `video_id`
  - `speakers`
- Videos without `speakers` will not display.
- Keep talks ordered by their actual presentation order. `schedule.yml` auto-maps empty slots from `videos.yml` in order, so published date order is not enough.
- Prefer the RubyEvents YouTube tools first. Use the Rails scripts when they are the better fit for a full-playlist import.
- When a published YouTube recording matches an existing `video_provider: "scheduled"` entry, keep the existing `title` and only update `raw_title` from YouTube metadata.

## Related Scripts

These scripts are documented in `docs/ADDING_VIDEOS.md` and are useful context for deciding the import path:

- `scripts/prepare_series.rb`: fills `youtube_channel_id` in `series.yml` from `youtube_channel_name`
- `scripts/create_events.rb`: creates `event.yml` files from playlists on a YouTube channel
- `scripts/extract_videos.rb`: regenerates an event `videos.yml` from the playlist ID in `event.yml`

Use `scripts/extract_videos.rb` when all of the following are true:

1. the user wants a whole playlist imported for one event
2. the playlist is the canonical event playlist
3. replacing or regenerating `videos.yml` is acceptable

This matters because `extract_videos.rb`:

- uses the playlist ID stored in `event.yml`
- honors `metadata_parser` from `event.yml`
- sorts by `published_at`, so you may still need to reorder the final file for schedule order
- does **not** finish the job by itself because `date` and sometimes `speakers` still need manual completion

## Tools to Prefer

- `rubyevents-event_lookup` to find the target event
- `rubyevents-youtube_playlist` to inspect playlist metadata
- `rubyevents-youtube_playlist_items` to fetch playlist videos
- `rubyevents-youtube_video` for a single video
- `rubyevents-youtube_videos` for batches of video IDs

Helpful supporting tools when needed:

- `rubyevents-speaker_lookup` to check whether speakers already exist
- `rubyevents-event_talks` to compare against existing talk records

## Workflow

1. Identify the target event and inspect:
   - `data/{series}/{event}/event.yml`
   - `data/{series}/{event}/videos.yml` if it already exists
2. Decide whether this is:
   - a **full playlist import**, or
   - a **partial import / append / update** from selected videos
3. Extract IDs from the user input:
   - playlist URL -> `list=...`
   - watch URL -> `v=...`
   - short URL -> path segment after `youtu.be/`
4. Fetch metadata:
   - playlist: use `rubyevents-youtube_playlist` and `rubyevents-youtube_playlist_items`
   - video list: use `rubyevents-youtube_video` or `rubyevents-youtube_videos`
5. Convert YouTube metadata into RubyEvents entries.
6. Merge into `videos.yml` without creating duplicates.
7. Reorder the file to match real talk order if the event has a schedule or multi-day structure.
8. Run `bin/lint`.

## Building Entries

Each imported YouTube talk should usually end up with fields like:

```yaml
- id: "speaker-or-title-event-slug"
  title: "Talk title"
  raw_title: "Original YouTube title"
  date: "YYYY-MM-DD"
  published_at: "YYYY-MM-DD"
  description: "Talk description"
  video_provider: "youtube"
  video_id: "abcdefghijk"
  speakers:
    - "Speaker Name"
```

Follow the repo's YouTube parsing conventions:

- remove the event name from the title when it is redundant for newly created YouTube entries
- keep `raw_title` when you normalize the title
- if you are updating an existing scheduled talk, preserve its curated `title` and only refresh `raw_title`
- split speaker suffixes the same way the parsers do:
  - `" by "`
  - `" & "`
  - `", "`
  - `" and "`
- keep keynote or lightning-talk session titles intact when the parser would normally do so

If `event.yml` specifies a custom `metadata_parser`, trust that behavior when using `scripts/extract_videos.rb`.

## Choosing the Edit Strategy

### Full playlist for one event

Prefer this path when the playlist represents the whole event:

1. confirm the target event
2. confirm the playlist ID
3. if needed, update `event.yml` so its `id` matches the playlist ID
4. run:

```bash
bin/rails runner scripts/extract_videos.rb <series-slug> <event-slug>
```

Then finish the file:

- replace placeholder or missing `date` values with real talk dates
- fix any missing or incorrect `speakers`
- reorder talks to match the event program, not YouTube publish order
- preserve or restore fields like `track`, slides, or other manual metadata if the file already had them

### Selected videos or partial playlist import

Do **not** use `scripts/extract_videos.rb` for this.

Instead:

1. fetch only the videos you need with the RubyEvents YouTube tools
2. map them into `videos.yml` entries
3. append new items or update matching items in place

Match existing entries by `video_id` first. If there is no existing `video_id` match, use the talk `id` only when you are sure it is the same talk. If the matched entry is a scheduled talk, preserve its existing `title` and only replace `raw_title`, `published_at`, `video_provider`, and `video_id`.

## Generator Guidance

The talk generator is useful for unpublished talks, but it is not the final source of truth for YouTube imports because it creates entries with:

- `video_provider: "scheduled"`
- `video_id: "<talk-id>"`

Only use the generator to bootstrap a missing `videos.yml` if that is genuinely helpful. For published YouTube recordings, make sure the final saved entry is a real YouTube entry.

## Date and Speaker Rules

- Never use the YouTube publish date as the talk date unless the event itself happened that day.
- For a single-day event, it is usually safe to use the event date for every imported talk.
- For multi-day events, do not guess when the correct day is unclear; ask the user or infer it from the schedule/title/playlist organization.
- If speakers cannot be derived confidently from the title or description, ask the user instead of inventing them.

## Speaker Records

If you add a speaker who is not already in `data/speakers.yml`, add the speaker record too when the task clearly includes that scope. Prefer including a GitHub handle when you can find one.

## Final Checks

- `videos.yml` is valid YAML
- every imported YouTube entry has real `date`, `published_at`, `video_id`, and `speakers`
- no duplicate `video_id` entries were introduced
- talk order matches the program, especially when `schedule.yml` exists
- `bin/lint` passes
