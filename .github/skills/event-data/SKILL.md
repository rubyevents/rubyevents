---
name: event-data
description: Guide for handling event data. Use when asked to update event data such as CFPs, Talks, Schedule, Sponsors, Involvements, or Videos. Use when updating any file in the /data/ directory.
---

# Important Notes
If something is unclear, use the AskUserTool to ask for clarification.
**Always use the generators if possible.**
The generators will create a file with the correct structure, and will help you avoid formatting errors.
If you do not have a paramter for the generator, do not pass it as a parameter.
The generaator will create a reasonable fault or TODO for someone else to fill out later.
`bin/lint` must be called before commiting any changes to confirm the structure of the file is correct.

# Adding a talk

Review documentation in docs/ADDING_UNPUBLISHED_TALKS.md.

Review the available parameters for the TalkGenerator.

```bash
bin/rails g talk --help
```

Create a command to reproduce the talk.

For example, if the user says "Create a lightning talk from Chris Hasiński, the title is Doom, and it's for the Ruby Community Conference".

```bash
bin/rails g talk --event ruby-community-conference-winter-edition-2026 --speaker "Chris Hasiński" --title "Doom" --kind lightning_talk
```

Exclude any missing parameters, and let the generator create TODOs for someone else to fill out later.

If the rubyevents MCP is available, and the user did not provide an event series slug and event, use the EventLookupTool to find the correct event.

Call the generator once per talk, and do not attempt to create multiple talks in one command.

Run `bin/lint` once all talks are added to confirm the structure.

# Generating a Schedule

Load Documentation from docs/ADDING_SCHEDULES.md into context.

Call the help command and review the available parameters for the ScheduleGenerator.

```bash
bin/rails g schedule --help
```

Create a command to approximate the schedule provided by the user.

Modify the yaml file to match the schedule exactly.

Run `bin/lint` to confirm the schedule structure.

# Generating a Sponsors file

Load Documentation from docs/ADDING_SPONSORS.md into context.

Review the available parameters for the SponsorGenerator.

```bash
bin/rails g sponsor --help
```

Generate the sponsor file with appropriate tiers and sponsor names. 

# Speakers

When updating speakers.yml, the structure is:

```yaml
- name: "Speaker Name"
  github: "github_handle"
  slug: "speaker-slug"
```

Other fields are permitted, but these are the fields I want you to focus on.
The GitHub handle is how we deduplicate speakers, and populate their profile, so the key should always be present.
These speakers are used for talks and involvements, so if a speaker is missing, you need to create a new record for them here.

If the GitHub is unknown:

```yaml
- name: "Speaker Name"
  github: ""
  slug: "speaker-slug"
```

If the speaker has multiple aliases, they'll be included as aliases.

```yaml
- name: "Speaker Name"
  github: "github_handle"
  slug: "speaker-slug"
  aliases:
    - name: "Other Name"
      slug: "other-slug"
```