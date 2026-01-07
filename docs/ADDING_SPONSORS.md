# Adding Sponsors to RubyEvents

This guide explains how to add sponsor information for conferences and events in the RubyEvents platform.

## Overview

Sponsor data is stored in YAML files within the conference/event directories. Each conference can have its own sponsors file that defines sponsor tiers and individual sponsor information.

## File Structure

Sponsors are stored in YAML files at:
```
data/{series-name}/{event-name}/sponsors.yml
```

For example:
- [`data/rubykaigi/rubykaigi-2025/sponsors.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/rubykaigi/rubykaigi-2025/sponsors.yml)
- [`data/railsconf/railsconf-2025/sponsors.yml`](https://github.com/rubyevents/rubyevents/blob/main/data/railsconf/railsconf-2025/sponsors.yml)

## YAML Structure

### Basic Structure

```yaml
---
- tiers:
    - name: "Tier Name"
      description: "Description of this sponsorship tier"
      level: 1  # Lower numbers = higher priority tiers
      sponsors:
        - name: "Company Name"
          website: https://example.com
          slug: CompanyName
          logo_url: https://example.com/logo.png
          badge: "Optional Badge Text"  # Optional: Special sponsor designation
```

### Complete Example

```yaml
---
- tiers:
    - name: Platinum Sponsors
      description: "Premium sponsors supporting the conference"
      level: 1
      sponsors:
        - name: "Example Corp"
          website: https://example.com
          slug: ExampleCorp
          logo_url: https://conference.org/images/sponsors/example.png
          badge: "Keynote Sponsor"

        - name: "Tech Company Inc."
          website: https://techcompany.com
          slug: TechCompanyInc
          logo_url: https://conference.org/images/sponsors/tech.png

    - name: Gold Sponsors
      description: "Gold tier sponsors"
      level: 2
      sponsors:
        - name: "StartupCo"
          website: https://startup.co
          slug: StartupCo
          logo_url: https://conference.org/images/sponsors/startup.png

    - name: Silver Sponsors
      description: "Silver tier sponsors"
      level: 3
      sponsors:
        - name: "Local Business LLC"
          website: https://localbiz.com
          slug: LocalBusinessLLC
          logo_url: https://conference.org/images/sponsors/local.png
```

## Field Descriptions

### Tier Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name of the sponsor tier (e.g., "Platinum Sponsors", "Gold Sponsors") |
| `description` | No | Optional description of the tier |
| `level` | Yes | Numeric priority level (0 = highest priority, displayed first) |
| `sponsors` | Yes | Array of sponsor objects in this tier |

### Sponsor Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Official company name |
| `website` | Yes | Full URL to sponsor's website |
| `slug` | Yes | URL-safe identifier (no spaces or special characters) |
| `logo_url` | Yes | Full URL to sponsor's logo image |
| `badge` | No | Special designation text (e.g., "Video Sponsor", "Lunch Sponsor") additional to the sponsor tier |

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

## Step-by-Step Guide

### 1. Check for Existing Sponsors File

First, check if a sponsors file already exists:

```bash
ls data/{series-name}/{event}/sponsors.yml
```

### 2. Create or Edit the Sponsors File

If the file doesn't exist, create it:

```bash
touch data/{series-name}/{event}/sponsors.yml
```

### 3. Gather Sponsor Information

For each sponsor, collect:
- Official company name
- Company website URL
- Logo image URL (preferably high-resolution)
- Sponsorship tier
- Any special designations

### 4. Structure the YAML

Start with the basic structure and add tiers in order of importance (lowest level number first):

```yaml
---
- tiers:
    - name: "Highest Tier"
      level: 1
      sponsors: []

    - name: "Next Tier"
      level: 2
      sponsors: []
```

### 5. Add Sponsors to Each Tier

Fill in the sponsor details for each tier:

```yaml
    sponsors:
      - name: "Company Name"
        website: "https://company.com"
        slug: "CompanyName"
        logo_url: "https://conference.org/sponsors/company-logo.png"
```

## Troubleshooting

### Common Issues

- **Invalid YAML syntax**: Check indentation (use spaces, not tabs)
- **Missing required fields**: Ensure all required properties are present
- **Old sponsor logos**: All sponsor logos listed in any sponsors file are associated with a sponsor, and the first logo stored is displayed

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your sponsors file in the appropriate directory
4. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
5. Run `bin/lint`
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing sponsors:
- Open an issue on GitHub
- Check existing sponsors files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
