# Adding Involvements to RubyEvents

This guide explains how to add involvement information (organizers, program committee members, volunteers, etc.) for conferences and events in the RubyEvents platform.

## Overview

Involvement data is stored in YAML files within the conference/event directories. Each conference can have its own involvements file that defines the people and organisations involved in the event and their roles.

## File Structure

Involvements are stored in YAML files at:
```
data/{series-name}/{event-name}/involvements.yml
```

For example:
- [`data/sfruby/sfruby-2025/involvements.yml`](/data/sfruby/sfruby-2025/involvements.yml)
- [`data/rubyconf/rubyconf-2024/involvements.yml`](/data/rubyconf/rubyconf-2024/involvements.yml)
- [`data/rubyconfth/rubyconfth-2026/involvements.yml`](/data/rubyconfth/rubyconfth-2026/involvements.yml)

All permitted fields are defined in [InvolvementSchema.](/app/schemas/involvement_schema.rb)

## Common Roles

Typical roles used in involvements:

- **Organizer** - Event organizers
- **Program Committee Member** - People who review and select talks
- **MC** - Master of ceremonies / host
- **Volunteer** - Event volunteers
- **Scholar** - Scholarship recipients
- **Guide** - Mentors for scholars

_Note that we use singular role names._

## Generation

Generate an involvements.yml in the correct folder using the InvolvementsGenerator!

```bash
bin/rails g involvements --event xoruby-salt-lake-city-2026 --name Organizer --users "Jim Remsik"
```

Check the usage instructions using help.

```bash
bin/rails g involvements --help
```

## Step-by-Step Guide

### 1. Check for Existing Involvements File

First, check if an involvements file already exists:

```bash
ls data/{series-name}/{event}/involvements.yml
```

### 2. Create or Edit the Involvements File

If the file doesn't exist, create it:

```bash
bin/rails g involvements --event <event-slug> --name <role-name> --users "Name One" "Name Two" --organisations "Org One" "Org Two"
```

### 3. Gather Involvement Information

For each role, collect:
- The role title
- Names of people who have this role
- Any organisations associated with the role (optional)

### 4. Format the yaml

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
- **Missing required fields**: Ensure `name` and `users` are present for each role entry
- **Empty users list**: Use `users: []` if a role only has organisations

## Submission Process

1. Fork the RubyEvents repository
2. Setup your dev environment following the steps in [CONTRIBUTING](/CONTRIBUTING.md)
3. Create your involvements file in the appropriate directory
4. Run `bin/rails db:seed` (or `bin/rails db:seed:all` if the event happened more than 6 months ago)
5. Run `bin/lint`
6. Run `bin/dev` and review the event on your dev server
7. Submit a pull request

## Need Help?

If you have questions about contributing involvements:
- Open an issue on GitHub
- Check existing involvements files for examples
- Reference this documentation

Your contributions help make RubyEvents a comprehensive resource for the Ruby community!
