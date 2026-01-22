# Adding Call for Proposals to RubyEvents

This guide explains how to add a CFP for conferences and events in the RubyEvents platform.

## Overview

CFP data is stored in YAML files within the conference/event directories. Each conference can have its own cfp file that describes multiple CFPs.

## File Structure

CFPs are stored in YAML files at:
```
data/{series-name}/{event-name}/cfp.yml
```

For example:
- [`data/blue-ridge-ruby/blue-ridge-ruby-2026/cfp.yml`](/data/blue-ridge-ruby/blue-ridge-ruby-2026/cfp.yml)
- [`data/sfruby/sfruby-2025/cfp.yml`](/data/sfruby/sfruby-2025/cfp.yml)

All permitted fields are defined in [CFPSchema.](/app/schemas/cfp_schema.rb)

## Generation

Generate a CFP using the CfpGenerator!

```bash
bin/rails g cfp --event-series=blue-ridge-ruby --event=blue-ridge-ruby-2026 --name="Call for Proposals" --link=https://blueridgeruby.com/cfp --start-date=2025-12-15 --end-date=2026-02-03
```

Check the usage instructions using help.

```bash
bin/rails g cfp --help
```

This will create a cfp.yml with a single CFP in it.
If you need to add additional CFPs for start-up demos or lightning talks, add another cfp using the same format to the array.

## Step-by-Step Guide

### 1. Check for Existing CFP File

First, check if a cfp file already exists:

```bash
ls data/{series-name}/{event}/cfp.yml
```

### 2. Create or Edit the cfp File

If the file doesn't exist, create it:

```bash
bin/rails g cfp --event-series=blue-ridge-ruby --event=blue-ridge-ruby-2026
```

### 3. Gather CFP Information

Check the event website or social media!

### 4. Structure the YAML

Start with the basic structure and add additional CFPs if necessary.

> [!TIP]
> Dates are structured as YEAR-MM-DD and stored as strings.

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

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your cfp file in the appropriate directory
4. Run `bin/lint`
5. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing cfps:
- Open an issue on GitHub
- Check existing cfp files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
