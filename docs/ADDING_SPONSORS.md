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

All permitted fields are defined in [SponsorsSchema](/app/schemas/sponsors_schema.rb). A sponsor entry names the organization by its `slug` in [`data/organizations.yml`](/data/organizations.yml), where the name, website, logo and description live (see [ADDING_ORGANIZATIONS.md](ADDING_ORGANIZATIONS.md)). The entry itself only carries what is specific to this sponsorship: `badge`, and `from`/`to` in a series' file.

## Common Sponsor Tiers

Typical tier hierarchy (with suggested level values):

1. **Diamond/Title Sponsors** (level: 1) - Highest tier, title sponsors
2. **Platinum Sponsors** (level: 2) - Premium sponsors
3. **Gold Sponsors** (level: 3) - Major sponsors
4. **Silver Sponsors** (level: 4) - Standard sponsors
5. **Bronze Sponsors** (level: 5) - Entry-level sponsors
6. **Community Sponsors** (level: 6) - Community supporters
7. **Media Partners** (level: 7) - Media and promotional partners

## Special Sponsor Types

Some sponsors may have special designations indicated by the `badge` field:

- **Event-specific sponsors**: "Opening Keynote Sponsor", "Closing Party Sponsor"
- **Service sponsors**: "Video Sponsor", "Live Stream Sponsor", "WiFi Sponsor"
- **Amenity sponsors**: "Coffee Sponsor", "Lunch Sponsor", "Snack Sponsor"
- **Activity sponsors**: "Workshop Sponsor", "Hackathon Sponsor"
- **Support sponsors**: "Scholarship Sponsor", "Diversity Sponsor"

## Generation

Generate a sponsors.yml in the correct folder using the SponsorsGenerator!

```bash
bin/rails g sponsors --event-series tropicalrb --event tropical-on-rails-2026
```

Add one sponsor per call. An organization that is already in `data/organizations.yml` only needs its slug; a new one needs `--name` (and `--website`, `--logo_url`), which also adds it to `data/organizations.yml`. If there is no tier, it will default to "Sponsors".

```bash
bin/rails g sponsors --event-series tropicalrb --event tropical-on-rails-2026 --slug typesense --tier Platinum
bin/rails g sponsors --event-series tropicalrb --event tropical-on-rails-2026 --name "Planet Argon" --website https://www.planetargon.com --tier Silver
```

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

- Its slug in `data/organizations.yml` (`grep -n 'name: "AppSignal"' data/organizations.yml`, or the `organization_lookup` MCP tool)
- For an organization that isn't there yet: official name, website URL and a logo image URL (preferably high-resolution)
- Sponsorship tier
- Any special designations

### 4. Structure the YAML

```yml
- slug: "appsignal"
  badge: "Wifi Sponsor"
```

A `badge` can be added for special sponsor designations. Name, website, logo and description belong to the organization in `data/organizations.yml`; a logo seen on the event website goes into its `logo_urls`.
We prefer organization names in English and latin characters if possible.

### 5. Format your yaml

Run the linter to automatically format and verify all required properties are present.

```bash
bin/lint
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

## Troubleshooting

### Common Issues

- **Invalid YAML syntax**: Check indentation (use spaces, not tabs)
- **Missing required fields**: Ensure all required properties are present
- **Unknown organization**: `bin/rails validate:sponsors` fails when a slug isn't in `data/organizations.yml`; add it with `bin/rails g organization` or `bin/rails organizations_file:add_missing`
- **Logos**: an organization shows its `logo_url`, or `app/assets/images/organizations/{slug}/logo.webp` when that exists; other logos are kept in `logo_urls`
- **Sponsors out of order**: Enter sponsors in the correct order in the file, which may not be how they are displayed

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your sponsors file in the appropriate directory
4. Run `bin/lint`
5. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing sponsors:

- Open an issue on GitHub
- Check existing sponsors files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
