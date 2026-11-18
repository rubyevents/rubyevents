# Adding Sponsors to RubyEvents

This guide explains how to add sponsor information for conferences and events in the RubyEvents platform.

## Overview

Sponsor data is stored in YAML files within the conference/event directories. Each conference can have its own sponsors file that defines sponsor tiers and individual sponsor information.

## File Structure

Sponsors are stored in YAML files at:

```yaml
data/{series-name}/{event-name}/sponsors.yml
```

For example:

- [`data/rubykaigi/rubykaigi-2025/sponsors.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/rubykaigi/rubykaigi-2025/sponsors.yml)
- [`data/railsconf/railsconf-2025/sponsors.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/railsconf/railsconf-2025/sponsors.yml)

All permitted fields are defined in [SponsorSchema.](/app/schemas/sponsor_schema.rb)

## Common Sponsor Tiers

Typical tier hierarchy (with suggested level values):

1. **Diamond/Title Sponsors** (level: 1) - Highest tier, title sponsors
2. **Platinum Sponsors** (level: 2) - Premium sponsors
3. **Gold Sponsors** (level: 3) - Major sponsors
4. **Silver Sponsors** (level: 4) - Standard sponsors
5. **Bronze Sponsors** (level: 5) - Entry-level sponsors
6. **Community Sponsors** (level: 6) - Community supporters
7. **Media Partners** (level: 7) - Media and promotional partners

## Generation

Generate a sponsors.yml in the correct folder using the SponsorsGenerator!

```bash
bin/rails g sponsors --event-series tropicalrb --event tropical-on-rails-2026
```

Pass multiple sponsors at once, and list the sponsor tier.
If there is no tier, it will default to "Sponsors".

```bash
bin/rails g sponsors typesense|Platinum AppSignal|Gold JetRockets|Gold "Planet Argon|Silver" --event-series tropicalrb --event tropical-on-rails-2026
```

If you are adding a new sponsor to an existing file, you can list all the sponsors as arguments and then use the merge tool when there's a conflict.
It'll feel very similar to resolving merge conflicts in git, but for different versions of the generated file.
Expect improvements to the generator for changes soon!

Check the usage instructions using help.

```bash
bin/rails g sponsors --help
```

## Step-by-Step Guide

### 1. Check for Existing Sponsors File

First, check if a sponsors file already exists:

```bash
ls data/{series-name}/{event}/sponsors.yml
```

### 2. Create or Edit the Sponsors File

If the file doesn't exist, create it:

```bash
bin/rails g sponsors --event-series tropicalrb --event tropical-on-rails-2026
```

### 3. Gather Sponsor Information

For each sponsor, collect:

- Official company name
- Company website URL
- Logo image URL (preferably high-resolution)
- Sponsorship tier
- Any special designations

### 4. Structure the YAML

Fill in the logo_url (from the event website) and website for each sponsor.

```yml
- name: "AppSignal"
  website: "https://www.appsignal.com/?utm_source=tropicalrb"
  slug: "Appsignal"
  logo_url: "https://framerusercontent.com/images/Ej8aWi209QFR5YrNB6Rl1aN8RqY.png"
```

Check for an existing sponsor in other sponsors files.
Ensure the company names and slugs match.
We prefer the sponsor names to be in English and use latin characters if possible.
A badge field can be added for special sponsor designations eg. "Wifi Sponsor"

### 5. Format your yaml

Run the linter to automatically format and verify all required properties are present.

```bash
bin/rails validate:all
```

### 5. Run seeds to load data

Run the event series seed to load data.

```bash
bundle exec rake db:seed:event_series[event-series-slug]
```

### 6. Review on your dev server

Start the dev server and review the event.

```bash
bin/dev
```

## FAQ

<details><summary>How do I handle special sponsor types, like WiFi or passport sponsors?</summary>
  Use the `badge` field to record special designations. Common examples include:

  - **Event-specific sponsors**: "Opening Keynote Sponsor", "Closing Party Sponsor"
  - **Service sponsors**: "Video Sponsor", "Live Stream Sponsor", "WiFi Sponsor"
  - **Amenity sponsors**: "Coffee Sponsor", "Lunch Sponsor", "Snack Sponsor", "Passport Sponsor"
  - **Activity sponsors**: "Workshop Sponsor", "Hackathon Sponsor"
  - **Support sponsors**: "Scholarship Sponsor", "Diversity Sponsor", "Travel Sponsor"
</details>

<details><summary>Why am I seeing an old logo instead of one I just added in the sponsors file?</summary>
  All sponsor logos listed in any sponsors file are associated with a sponsor, and the first logo stored is displayed.
  If you would like a different logo, open an issue or comment on the relevant PR, and a site admin can update the logo in production.
</details>

<details><summary>Should I use the company's brand name or its legal name?</summary>
  Always use the name the sponsor prefers and has asked us to display if one exists.
  If they haven't contacted us, use the name as it appears in the sponsor's logo or image for the event.
  If different event logos conflict, fall back to the name in the logo on the sponsor's website.
  We match based on domain, but ideally the name will be the same across files.
</details>

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your sponsors file in the appropriate directory
4. Run `bin/rails validate:all`
5. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing sponsors:

- Open an issue on GitHub
- Check existing sponsors files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
