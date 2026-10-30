# Adding & Updating Organizations on RubyEvents

Organizations are the companies, communities and foundations that sponsor events or organize them. Like speakers in `data/speakers.yml`, they live in one global file, and the event files reference them by slug.

## Overview

- **Organization identity, website, logos, description** → `data/organizations.yml`
- **Who sponsored which event, in which tier, with which badge** → `sponsors.yml` of the event or series
- **Which organization held which role at an event** → `involvements.yml` of the event or series

## File Structure

```
data/organizations.yml
```

All permitted fields are defined in [OrganizationSchema](/app/schemas/organization_schema.rb). Entries are sorted by slug.

### Fields

| Field | Required | Notes |
|---|---|---|
| `slug` | Yes | URL-friendly, lowercase, dashes; what `sponsors.yml` and `involvements.yml` reference |
| `aliases` | No | Array of `{name, slug}` pairs: former slugs that redirect to this organization, with the name they were known under |
| `name` | Yes | Name of the organization |
| `alternate_names` | No | Other spellings and former names, kept for search and history |
| `kind` | No | One of `company`, `community`, `foundation`, `non_profit`, `organisation` |
| `website` | No | Website URL shown on the organization page |
| `websites` | No | Other URLs seen for the organization (careers pages, regional sites) |
| `logo_url` | No | URL of the logo to show, unless `app/assets/images/organizations/{slug}/logo.webp` exists |
| `logo_urls` | No | Other logo URLs seen for the organization |
| `logo_background` | No | `white` (default), `black` or `transparent` |
| `main_location` | No | Where the organization is based (City, Country) |
| `description` | No | Description shown on the organization page |

Example entry:

```yaml
- slug: "appsignal"
  aliases:
    - name: "App Signal"
      slug: "app-signal"
  name: "AppSignal"
  alternate_names:
    - "Appsignal"
  website: "https://www.appsignal.com"
  websites:
    - "https://www.appsignal.com/ruby"
  logo_url: "https://rubyonrails.org/assets/world/2023/images/sponsors/RW-logo-appsignal.svg"
  logo_urls:
    - "https://rubyconf.org/images/uploads/appsignal.png"
```

## Generation

```bash
bin/rails g organization --name "AppSignal" --website https://www.appsignal.com --logo_url https://example.com/appsignal.svg
bin/rails g organization --slug appsignal --kind company --main_location "Amsterdam, Netherlands"
bin/rails g organization --help
```

Adding a sponsor with `bin/rails g sponsors --name ... --website ...` adds the organization as well when its slug isn't known yet. The MCP tools `organization_lookup`, `organization_create`, `organization_update` and `organization_add_alias` do the same for agents.

## Common Contributions

### Adding a logo, website or description

Find the entry by slug (`grep -n 'slug: "appsignal"' data/organizations.yml`) and add the field. `bin/rails validate:organizations` checks the file.

### Merging duplicates

The same organization sometimes got two slugs from two events (`scout-apm`, `scoutapm`). `bin/rails organizations_file:duplicates` lists candidates: organizations sharing a website domain or with near-identical names. Merging is a human decision:

```bash
bin/rails g organization --slug scoutapm --alias-slug scout-apm --alias-name "Scout APM"
bin/rails organizations_file:extract
```

The alias keeps the old URL `/organizations/scout-apm` working, and `organizations_file:extract` rewrites every `sponsors.yml` and `involvements.yml` that used the old slug. Remove the duplicate's own entry; put anything worth keeping (other websites, logos, spellings) on the kept entry.

### Renaming

Change `name` and keep the old spelling in `alternate_names`. Changing `slug` works the same way as merging: the old slug goes into `aliases`, then run `bin/rails organizations_file:extract`.

## How the import treats the database

`bin/rails db:seed` writes the file into the `organizations` table:

- `name`, `website` and `description` follow the YAML whenever it has a value.
- `kind`, `main_location`, `logo_background` and `logo_url` only fill a blank column, so what admins picked in Avo or the logo picker survives a seed. The seed prints a warning when the logo an organization shows is missing from its `logo_urls`.
- `logo_urls` are added to the column, never removed.
- An organization found through an alias slug is renamed to the current slug; the old slug stays as alias.

## Tasks

```bash
bin/rails organizations_file:stats        # counts, missing, orphaned, duplicates
bin/rails organizations_file:missing      # slugs referenced in sponsors/involvements but not in the file
bin/rails organizations_file:add_missing  # adds them, named after their slug, for you to fill in
bin/rails organizations_file:orphaned     # entries nothing references
bin/rails organizations_file:sync         # add missing, remove orphaned
bin/rails organizations_file:duplicates   # candidates to merge by hand
bin/rails validate:organizations          # schema, unique slugs and names, slug format, website URLs
```

## Submission Process

1. Fork the RubyEvents repository
2. Edit `data/organizations.yml` (and the event's `sponsors.yml` or `involvements.yml`)
3. Run `bin/lint`
4. Run `bin/rails db:seed:organizations` and `bin/rails db:seed:event_series[series-slug]`
5. Run `bin/dev` and review `/organizations/{slug}`
6. Submit a pull request
