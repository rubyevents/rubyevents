---
title: "Announcement system documentation"
slug: announcement-system-documentation
date: 2026-01-22
author: adrienpoly
published: false
excerpt: "Here is a list of shortcuts and documentation for the announcement system."
tags:
  - documentation
featured_image:
---

We've added some shortcuts and documentation to the announcement system to make it easier to use. These shortcuts allow you to create rich, interconnected content that links to existing resources on RubyEvents.org.

## Shortcuts

### Mentions

You can mention users with the `@username` syntax. When the username matches a registered user, it will automatically be converted to a link to their profile.

**Syntax:**

```markdown
@username
```

**Example:**

Check out @adrienpoly's profile.

### Topics

You can link to topics using the wiki-link syntax `[[topic-slug]]`. When the topic exists, it will be converted to a link to that topic's page.

**Syntax:**

```markdown
[[topic-slug]]
```

**Examples:**

- [[hotwire]]
- [[web-components]]
- [[rails]]

This is great for connecting announcements to relevant topic pages, helping readers discover more content.

## Writing Announcements

Announcements support full Markdown syntax including:

### Styling text

| Style | Syntax | Example | Output |
|-------|--------|---------|--------|
| Bold | `** **` or `__ __` | `**This is bold text**` |**This is bold text** |
| Italic | `* *` or `_ _` | `_This text is italicized_` |_This text is italicized_ |
| Strikethrough | `~~ ~~` or `~ ~` | `~~This was mistaken text~~` | ~~This was mistaken text~~ |
| Bold and nested italic | `** **` and `_ _` | `**This text is _extremely_ important**` | **This text is _extremely_ important** |
| All bold and italic | `*** ***` | `***All this text is important***` | ***All this text is important*** |
| Subscript | `<sub> </sub>` | `This is a <sub>subscript</sub> text` | This is a <sub>subscript</sub> text |
| Superscript | `<sup> </sup>` | `This is a <sup>superscript</sup> text` | This is a <sup>superscript</sup> text |
| Underline | `<ins> </ins>` | `This is an <ins>underlined</ins> text` | This is an <ins>underlined</ins> text |
| Links | `[Text](URL)` | `[RubyEvents](https://www.rubyevents.org)` | [RubyEvents](https://www.rubyevents.org) |


### Code blocks with syntax highlighting

**Example:**

```ruby
def hello_world
  puts "Hello, world!"
end
```


### Tables

```markdown
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Row 1    | Row 1    | Row 1    |
| Row 2    | Row 2    | Row 2    |
| Row 3    | Row 3    | Row 3    |
```

**Example:**

| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Row 1    | Row 1    | Row 1    |
| Row 2    | Row 2    | Row 2    |
| Row 3    | Row 3    | Row 3    |

### Lists

```markdown
- Item 1
- Item 2
- Item 3
```

**Example:**

- Item 1
- Item 2
- Item 3

### Frontmatter Options

Each announcement requires a YAML frontmatter with the following fields:

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | The announcement title |
| `slug` | Yes | URL-friendly identifier |
| `date` | Yes | Publication date (YYYY-MM-DD) |
| `author` | Yes | GitHub username of the author |
| `published` | Yes | Set to `true` to publish |
| `excerpt` | No | Short description for previews |
| `tags` | No | List of tags for categorization |
| `featured_image` | No | URL or path to a featured image |

## Tips

1. **Check usernames exist** - Mentions only link if the user is registered on RubyEvents.org
2. **Use topic slugs** - Topics are matched by slug or name, but slugs are more reliable
3. **Preview before publishing** - Set `published: false` to preview your announcement locally before going live
