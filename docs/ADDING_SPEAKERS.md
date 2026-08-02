# Adding & Updating Speakers on RubyEvents

This guide is for speakers (or anyone on their behalf) who want to fill out or improve a speaker profile: identity, social links, and resources related to their talks. Speakers are uniquely positioned to add detail that's otherwise hard for maintainers to find, so contributions here are especially welcome.

## Overview

Speaker profiles are stored globally in a single file, separate from any one event. Additional resources for a specific talk (slides, blog posts, source code, etc.) live with that talk instead.

- **Speaker identity & social links** → `data/speakers.yml`
- **Slides, blog posts, and other talk resources** → `additional_resources` on the talk in the event's `videos.yml`

## File Structure

Speakers are stored in a single global file:

```
data/speakers.yml
```

All permitted fields are defined in [SpeakerSchema.](/app/schemas/speaker_schema.rb)

### Fields

| Field | Required | Notes |
|---|---|---|
| `name` | Yes | Full name of the speaker |
| `slug` | Yes | URL-friendly slug, must be unique |
| `github` | Yes | GitHub **username only**, not a URL (e.g. `"tenderlove"`, not `"https://github.com/tenderlove"`) |
| `twitter` | No | Twitter/X handle, no `@`, not a URL |
| `bluesky` | No | Bluesky handle, not a URL (e.g. `"tenderlove.dev"`) |
| `mastodon` | No | Full Mastodon profile **URL** (e.g. `"https://ruby.social/@tenderlove"`) |
| `linkedin` | No | The part of the URL after `/in/`, not a full URL |
| `speakerdeck` | No | Speakerdeck username, not a URL |
| `website` | No | Personal website URL |
| `aliases` | No | Array of `{name, slug}` pairs that redirect to this profile |
| `canonical_slug` | No | Slug of another speaker this one should be merged into (deduplication) |

> [!IMPORTANT]
> GitHub is the unique identifier we use throughout the site to deduplicate speakers, authenticate users, and populate profiles. If you only add one field beyond `name`, make it `github`.

Example entry:

```yaml
- name: "Aaron Patterson"
  github: "tenderlove"
  twitter: "tenderlove"
  mastodon: "https://mastodon.social/@tenderlove"
  bluesky: "tenderlove.dev"
  website: "https://tenderlovemaking.com/"
  speakerdeck: "tenderlove"
  slug: "aaron-patterson"
```

## Common Contributions

### Updating your name, aliases, or identity

If you need to rename, merge, or de-duplicate a profile (e.g. two entries for the same person, or a name change), see the dedicated guide: [FIXING_PROFILE_NAMES.md](FIXING_PROFILE_NAMES.md). Aliases ensure old URLs keep redirecting and that past or future talks still get associated with the right speaker.

### Adding your GitHub handle

Find your entry in `data/speakers.yml` (speakers are sorted alphabetically by name) and add or correct the `github` field with your **username** (not a URL):

```yaml
- name: "Jane Doe"
  github: "janedoe"
  slug: "jane-doe"
```

If your entry doesn't exist yet, add a new one. `name`, `slug`, and `github` are required.

### Adding social links

Add any of `twitter`, `bluesky`, `mastodon`, `linkedin`, `speakerdeck`, or `website` to your entry. See the [Fields](#fields) table above for the exact format each one expects — most are bare handles, not full URLs.

### Adding slides

Slides belong to a specific talk, not to your speaker profile. Add them as an `additional_resources` entry on the talk in that event's `videos.yml` (see [ADDING_UNPUBLISHED_TALKS.md](ADDING_UNPUBLISHED_TALKS.md) for the full talk file structure):

```yaml
- id: "jane-doe-example-conf-2026"
  title: "My Great Talk"
  # ...
  additional_resources:
    - name: "Slides"
      type: "presentation"
      url: "https://speakerdeck.com/janedoe/my-great-talk"
```

If you use Speakerdeck consistently, adding your `speakerdeck` username to `speakers.yml` is also worthwhile — it's used to surface your decks across the site.

### Adding blog posts, write-ups, or other resources

Also added via `additional_resources` on the talk in `videos.yml`:

```yaml
additional_resources:
  - name: "Blog Post"
    type: "blog"
    url: "https://janedoe.dev/posts/my-great-talk"
    title: "My Great Talk: The Write-up" # optional, full title
```

`type` must be one of the values defined in [AdditionalResourceSchema](/app/schemas/additional_resource_schema.rb): `write-up`, `blog`, `article`, `source-code`, `code`, `repo`, `github`, `documentation`, `docs`, `presentation`, `video`, `podcast`, `audio`, `gem`, `library`, `transcript`, `handout`, `notes`, `photos`, `link`, `book`.

A talk can have multiple `additional_resources` entries — add one per resource.

## Step-by-Step Guide

### 1. Find your existing entry (if any)

```bash
grep -A 5 '"Your Name"' data/speakers.yml
```

If you're not sure whether an entry already exists under a slightly different name, check for near-duplicates too — see [Troubleshooting](#troubleshooting) below.

### 2. Edit or add your entry

Update the fields described above, or add a new entry with at least `name`, `slug`, and `github`.

### 3. For talk-specific resources, edit the event's `videos.yml`

Find the talk in `data/{series-slug}/{event-slug}/videos.yml` and add `additional_resources` as shown above.

### 4. Format your yaml

```bash
bundle exec yerba apply
```

This formats `data/speakers.yml`, sorts speakers alphabetically by name, and validates the file against the schema.

### 5. Run seeds to load data

```bash
bin/rails db:seed:speakers
```

This reimports all speakers and is fast, making it great for iterating on profile changes. If you also changed a `videos.yml`, seed that event series too:

```bash
bin/rails db:seed:event_series[event-series-slug]
```

### 6. Review on your dev server

```bash
bin/dev
```

Visit your speaker profile and the talk page to confirm the changes look right.

## Troubleshooting

### Common Issues

- **`github` looks like a URL**: The `github`, `twitter`, `bluesky`, `linkedin`, and `speakerdeck` fields must be bare usernames/handles, not URLs. `mastodon` is the exception — it must be a full profile URL.
- **Duplicate `slug`, `github`, `twitter`, `speakerdeck`, `mastodon`, or `bluesky`**: Each of these fields must be unique across `speakers.yml`. `bin/lint` will report the conflicting entries.
- **Similar names flagged without a social handle**: If two speaker names are very close (a likely typo or accent difference), the linter asks you to add a distinguishing social handle to confirm they're different people, or merge them via an alias if they're the same.
- **`Speaker "X" not found in data/speakers.yml`**: A `videos.yml` or `involvements.yml` references a speaker name that doesn't have a matching entry (or alias) in `speakers.yml`. Add the speaker there first.
- **Invalid resource `type`**: Check that `additional_resources` entries use one of the allowed `type` values listed above.

Run `bin/lint` to catch all of the above before submitting.

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Update `data/speakers.yml` and/or the relevant `videos.yml`
4. Run `bin/lint`
5. Run `bin/rails db:seed:speakers` (and `bin/rails db:seed:event_series[series-slug]` if you touched a `videos.yml`)
6. Run `bin/dev` and review the profile/talk on your dev server
7. Submit a pull request

## Need Help?

If you have questions about updating your speaker profile:

- Open an issue on GitHub
- Check existing entries in `data/speakers.yml` for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
