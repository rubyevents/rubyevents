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

## YAML Structure

### Basic Structure

```yaml
---
- name: "Role Name"
  users:
    - Person Name
    - Another Person
  organisations:  # Optional
    - Organisation Name
```

### Complete Example

```yaml
---
- name: "Organizer"
  users:
    - Irina Nazarova
  organisations:
    - Evil Martians

- name: "Program Committee Member"
  users:
    - Maple Ong
    - Cameron Dutro
    - Noel Rappin
    - Vladimir Dementyev

- name: "Volunteer"
  users:
    - Daniel Azuma
    - Todd Kummer
    - Ken Decanio
```

## Field Descriptions

### Role Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | The role title (e.g., "Organizer", "Program Committee Member", "MC") |
| `users` | Yes | Array of user names who have this role - matched to [speakers.yml](data/speakers.yml) |
| `organisations` | No | Array of organisation names - matched with existing organisations |

## Common Roles

Typical roles used in involvements:

- **Organizer** - Event organizers
- **Program Committee Member** - People who review and select talks
- **MC** - Master of ceremonies / host
- **Volunteer** - Event volunteers
- **Scholar** - Scholarship recipients
- **Guide** - Mentors for scholars

## Step-by-Step Guide

### 1. Check for Existing Involvements File

First, check if an involvements file already exists:

```bash
ls data/{series-name}/{event}/involvements.yml
```

### 2. Create or Edit the Involvements File

If the file doesn't exist, create it:

```bash
touch data/{series-name}/{event}/involvements.yml
```

### 3. Gather Involvement Information

For each role, collect:
- The role title
- Names of people who have this role
- Any organisations associated with the role (optional)

### 4. Structure the YAML

Create the basic template, and replace with your involvement information.
If you need to provide additional details for an organisation, you can add that organisation to sponsors.yml.
(See RubyConf TH 2026 for an example.)

```yaml
---
- name: "Organizer"
  users:
    - Name
  organisations:
    - Organisation Name

- name: "Volunteer"
  users:
    - Volunteer One
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
