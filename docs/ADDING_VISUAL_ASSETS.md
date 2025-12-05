# Adding Visual Assets to Events

This guide explains how to add and manage visual assets (images) for events in RubyEvents.

## Overview

Each event can have multiple visual assets that are used throughout the platform for different purposes. These assets are stored in the `app/assets/images/events/{organization}/{event}/` directory.

## Asset Types

RubyEvents supports the following asset types:

| Asset Type | Dimensions | Purpose |
|------------|------------|---------|
| `avatar.webp` | 256×256 | Small circular profile images, used in listings |
| `banner.webp` | 1300×350 | Wide header images for event pages |
| `card.webp` | 600×350 | Card thumbnails used in grid layouts |
| `featured.webp` | 615×350 | Featured event displays on homepage |
| `poster.webp` | 600×350 | Event poster/promotional image |
| `sticker.webp` | 350×350 | Digital sticker graphics (can have multiple: sticker-1.webp, sticker-2.webp, etc.) |
| `stamp.webp` | 512×512 | Digital stamp graphics (can have multiple: stamp.webp, stamp-1.webp, etc.) |

## File Location

Assets should be placed in:
```
app/assets/images/events/{organization-slug}/{event-slug}/
```

For example:
```
app/assets/images/events/railsconf/railsconf-2025/
├── avatar.webp
├── banner.webp
├── card.webp
├── featured.webp
├── poster.webp
├── sticker.webp
└── stamp.webp
```

## Image Format

- All images must be in **WebP format** for optimal performance
- Images should be exported at the exact dimensions specified above
- Use `save-for-web` optimization when exporting

## Brand Colors

In addition to images, you can specify brand colors for your event in its `event.yml` file:

```yaml
# data/railsconf/railsconf-2025/event.yml
---
id: railsconf-2025
title: RailsConf 2025
# ... other fields ...
banner_background: "#FF0000"      # Background color for banner
featured_background: "#000000"    # Background color for featured display
featured_color: "#FFFFFF"         # Text color for featured display
```

These colors support:
- Hex colors (e.g., `#FF0000`)
- RGB/RGBA colors (e.g., `rgb(255, 0, 0)`)
- CSS gradients (e.g., `linear-gradient(90deg, #FF0000, #0000FF)`)

## Exporting Assets from Sketch

If you're using the RubyEvents Sketch file, you can export assets using rake tasks:

### Export all assets for a specific event:
```bash
rake export_assets[event-slug]
```

### Export all assets for all events:
```bash
rake export_assets
```

### Export stickers:
```bash
rake export_stickers
```

### Export stamps by country code:
```bash
rake export_stamps[US]
```

## Viewing All Assets

You can view all event assets and their status at:
[https://rubyevents.org/pages/assets](https://rubyevents.org/pages/assets)


## Default/Fallback Assets

If an event doesn't have specific assets, the system will fall back to:
1. Organization-level defaults (in `app/assets/images/events/{organization}/default/`)
2. Global defaults (in `app/assets/images/events/default/`)

## Step-by-Step Guide

### 1. Prepare Your Images

Create images at the correct dimensions in your design tool (Sketch, Figma, etc.).

### 2. Export as WebP

Export each image as WebP format with web optimization enabled.

### 3. Name Your Files

Use the exact filenames specified above:
- `avatar.webp`
- `banner.webp`
- `card.webp`
- `featured.webp`
- `poster.webp`
- `sticker.webp` (or `sticker-1.webp`, `sticker-2.webp` for multiple)
- `stamp.webp` (or `stamp-1.webp`, `stamp-2.webp` for multiple)

### 4. Place Files in Correct Directory

Create the directory structure if it doesn't exist:
```bash
mkdir -p app/assets/images/events/{organization-slug}/{event-slug}
```

Copy your assets to this directory.

### 5. Add Brand Colors

Edit the event's `event.yml` file at `data/{organization}/{event-slug}/event.yml` to add brand colors:

```yaml
banner_background: "#your-color"
featured_background: "#your-color"
featured_color: "#your-color"
```

### 6. Verify Assets

Visit https://rubyevents.org/pages/assets (or your local development server at http://localhost:3000/pages/assets) to verify all assets are displaying correctly.

## Troubleshooting

### Assets not appearing
- Check the file path is correct
- Verify the filename matches exactly (including `.webp` extension)
- Ensure proper file permissions
- Clear asset cache with `rails assets:clobber`

### Wrong dimensions
- Re-export the image at the correct dimensions
- Don't rely on CSS to resize images

### Color not applied
- Verify the color value in `event.yml`
- Check the color format is valid CSS
- Restart the server after changing `event.yml`
