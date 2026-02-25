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

The full schema for a video is available in [VideoSchema](app/schemas/video_schema.rb).

### 1. Check for Existing Videos File

First, check if a videos file already exists:

```bash
ls data/{series-name}/{event-name}/videos.yml
```

### 2. Create or Edit the Videos File

If the file doesn't exist, create it by calling the generator with the first talk.

```bash
bin/rails generate talk --event-series blue-ridge-ruby --event blue-ridge-ruby-2026 --title "Your first open-source contribution" --speaker "Rachael Wright-Munn" --description ""
```

Check the usage instructions using `--help`.

```bash
bin/rails g talk --help
```

Call the generator multiple times to add multiple talks to the event.

Pass multiple speakers per talk in by passing multiple names to the argument.

```bash
bin/rails generate talk --event-series blue-ridge-ruby --event blue-ridge-ruby-2026 --title "RubyEvents is great!" --speaker "Marco Roth" "Rachael Wright-Munn"
```

### 3. Gather Talk Information

For each talk, collect:
- Talk title
- Speaker name(s)
- Date of the talk
- Video URL (if available) or use "scheduled" for upcoming talks
- Description (if available)
- Any additional resources (slides, blog posts, etc.)

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

### FAQ
<details><summary>How do I handle talks that are not in English?</summary>
  For talks that are not in English, we prefer English descriptions and titles if provided by the event.
  If those are not provided, use the original language for the description, translate the title to English, and store the title in its original language in original_title.

  ```yaml
  - id: "name-talk-type-event-name-year"
    title: "Talk title in English"
    original_title: "Talk title in original language"
    description: "Description in original language"
  ```
</details>

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create or update the videos.yml file in the appropriate directory
4. Run `bin/lint`
5. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing talks:
- Open an issue on GitHub
- Check existing videos.yml files for examples (e.g., `data/rubyconfth/rubyconfth-2026/videos.yml`)
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
