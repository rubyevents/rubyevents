#!/usr/bin/env node

/**
 * Migration script to convert meetup data from combined videos.yml
 * to individual event folders (matching conference structure).
 *
 * Usage:
 *   node scripts/migrate_meetups.mjs --dry-run              # Preview changes
 *   node scripts/migrate_meetups.mjs --series=sf-bay-area-ruby  # Single series
 *   node scripts/migrate_meetups.mjs                        # Full migration
 */

import fs from 'fs'
import path from 'path'
import YAML, { Document } from 'yaml'

// Parse CLI arguments
const args = process.argv.slice(2)
const CONFIG = {
  dryRun: args.includes('--dry-run'),
  verbose: args.includes('--verbose'),
  seriesFilter: args.find(a => a.startsWith('--series='))?.split('=')[1],
  dataDir: args.find(a => a.startsWith('--data-dir='))?.split('=')[1] || './data'
}

const DATA_DIR = CONFIG.dataDir

const YAML_OPTIONS = {
  indent: 2,
  lineWidth: 180,
  simpleKeys: true,
  singleQuote: false,
  collectionStyle: 'block',
  blockQuote: 'literal',
  defaultStringType: 'QUOTE_DOUBLE',
  directives: true,
  doubleQuotedMinMultiLineLength: 80
}

/**
 * Convert an object to a properly formatted YAML string
 */
function toYaml(obj, { spaceBetweenItems = false } = {}) {
  const doc = new Document(obj)

  // Add blank lines between top-level array items if requested
  if (spaceBetweenItems && doc.contents && doc.contents.items) {
    doc.contents.items.forEach((item, index) => {
      if (index > 0) {
        item.spaceBefore = true
      }
    })
  }

  // Visit all pairs to ensure proper formatting
  YAML.visit(doc, {
    Pair(_, pair) {
      const { key, value } = pair

      // Ensure keys are unquoted (PLAIN)
      if (key && key.type !== 'PLAIN') {
        key.type = 'PLAIN'
      }

      // Quote string values
      if (value && typeof value.value === 'string' && value.type === 'PLAIN') {
        pair.value.type = 'QUOTE_DOUBLE'
      }

      // Use block literal for description fields
      if (key && key.value === 'description' && value && typeof value.value === 'string') {
        pair.value.type = 'BLOCK_LITERAL'
      }
    }
  })

  return doc.toString(YAML_OPTIONS)
}

const MONTH_NAMES = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december'
]

/**
 * Find all meetup folders (ending in -meetup) that contain videos.yml
 */
function findMeetupFolders() {
  const meetups = []
  const seriesDirs = fs.readdirSync(DATA_DIR)

  for (const seriesDir of seriesDirs) {
    const seriesPath = path.join(DATA_DIR, seriesDir)
    if (!fs.statSync(seriesPath).isDirectory()) continue

    // Apply series filter if specified
    if (CONFIG.seriesFilter && seriesDir !== CONFIG.seriesFilter) continue

    const subDirs = fs.readdirSync(seriesPath)
    for (const subDir of subDirs) {
      if (!subDir.endsWith('-meetup')) continue

      const meetupPath = path.join(seriesPath, subDir)
      const videosPath = path.join(meetupPath, 'videos.yml')

      if (fs.existsSync(videosPath)) {
        meetups.push({
          seriesSlug: seriesDir,
          meetupSlug: subDir,
          seriesPath,
          meetupPath,
          videosPath
        })
      }
    }
  }

  return meetups
}

/**
 * Extract year-month from date string
 * "2024-03-28" → "2024-03"
 */
function extractYearMonth(dateStr) {
  if (!dateStr) return null
  const match = dateStr.match(/^(\d{4})-(\d{2})/)
  return match ? `${match[1]}-${match[2]}` : null
}

/**
 * Get month name from date string
 * "2024-03-28" → "march"
 */
function getMonthName(dateStr) {
  if (!dateStr) return null
  const match = dateStr.match(/^(\d{4})-(\d{2})/)
  if (!match) return null
  const monthIndex = parseInt(match[2], 10) - 1
  return MONTH_NAMES[monthIndex]
}

/**
 * Generate slug from title
 * "SF Bay Area Ruby Meetup - March 2024" → "sf-bay-area-ruby-meetup-march-2024"
 */
function generateSlug(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

/**
 * Generate a talk ID from speaker names and event info
 */
function generateTalkId(talk, eventSlug) {
  const speakers = talk.speakers || []
  if (speakers.length === 0) {
    // Use title-based ID
    const titleSlug = generateSlug(talk.title || 'unknown')
    return `${titleSlug}-${eventSlug}`
  }

  // Use first speaker's name
  const speakerSlug = generateSlug(speakers[0])
  return `${speakerSlug}-${eventSlug}`
}

/**
 * Transform a meetup entry's talks into flat video entries
 */
function transformTalks(meetupEntry, eventSlug) {
  const talks = meetupEntry.talks || []
  const parentVideoProvider = meetupEntry.video_provider
  const parentVideoId = meetupEntry.video_id
  const parentDate = meetupEntry.date
  const parentEventName = meetupEntry.event_name || meetupEntry.title
  const parentPublishedAt = meetupEntry.published_at

  return talks.map(talk => {
    const video = {
      title: talk.title
    }

    // Generate unique ID
    video.id = talk.video_id || generateTalkId(talk, eventSlug)

    // Handle video provider based on parent type
    if (parentVideoProvider === 'youtube' && talk.video_provider === 'parent') {
      // Parent is a YouTube video, talks reference it via timestamps
      video.video_provider = 'youtube'
      video.video_id = parentVideoId
    } else if (parentVideoProvider === 'children') {
      // Children have their own video info
      video.video_provider = talk.video_provider
      // Preserve video_id for all children (including not_recorded, scheduled, etc.)
      if (talk.video_id) {
        video.video_id = talk.video_id
      }
    } else {
      // Preserve original video info
      video.video_provider = talk.video_provider || parentVideoProvider
      // Always preserve video_id if present
      if (talk.video_id) {
        video.video_id = talk.video_id
      }
    }

    // Timing info
    if (talk.start_cue) video.start_cue = talk.start_cue
    if (talk.end_cue) video.end_cue = talk.end_cue

    // Date and event info
    video.date = talk.date || parentDate
    video.event_name = talk.event_name || parentEventName

    // Published at
    if (talk.published_at) {
      video.published_at = talk.published_at
    } else if (parentPublishedAt) {
      video.published_at = parentPublishedAt
    }

    // Speakers
    if (talk.speakers && talk.speakers.length > 0) {
      video.speakers = talk.speakers
    }

    // Description
    if (talk.description) {
      video.description = talk.description
    }

    // Slides
    if (talk.slides_url) {
      video.slides_url = talk.slides_url
    }

    // Thumbnails
    if (talk.thumbnail_xs) video.thumbnail_xs = talk.thumbnail_xs
    if (talk.thumbnail_sm) video.thumbnail_sm = talk.thumbnail_sm
    if (talk.thumbnail_md) video.thumbnail_md = talk.thumbnail_md
    if (talk.thumbnail_lg) video.thumbnail_lg = talk.thumbnail_lg
    if (talk.thumbnail_xl) video.thumbnail_xl = talk.thumbnail_xl

    // Language
    if (talk.language) video.language = talk.language

    return video
  })
}

/**
 * Generate event.yml content
 */
function generateEventYml(meetupEntry, originalEvent, eventId) {
  const title = meetupEntry.title || meetupEntry.event_name
  const date = meetupEntry.date

  const event = {
    id: eventId,
    title: title,
    kind: 'meetup',
    location: originalEvent.location || '',
    start_date: date,
    end_date: date
  }

  // Published at
  if (meetupEntry.published_at && meetupEntry.published_at !== 'TODO') {
    event.published_at = meetupEntry.published_at
  }

  // Description from meetup entry
  if (meetupEntry.description) {
    event.description = meetupEntry.description
  }

  // Styling from original event
  if (originalEvent.banner_background) {
    event.banner_background = originalEvent.banner_background
  }
  if (originalEvent.featured_background) {
    event.featured_background = originalEvent.featured_background
  }
  if (originalEvent.featured_color) {
    event.featured_color = originalEvent.featured_color
  }

  return event
}

/**
 * Process a single meetup folder
 */
function processMeetup(meetupInfo) {
  const { seriesSlug, meetupSlug, seriesPath, meetupPath, videosPath } = meetupInfo

  console.log(`\nProcessing: ${seriesSlug}/${meetupSlug}`)

  // Read original event.yml for defaults
  const originalEventPath = path.join(meetupPath, 'event.yml')
  let originalEvent = {}
  if (fs.existsSync(originalEventPath)) {
    originalEvent = YAML.parse(fs.readFileSync(originalEventPath, 'utf8')) || {}
  }

  // Read videos.yml
  const videosContent = fs.readFileSync(videosPath, 'utf8')
  const meetups = YAML.parse(videosContent)

  if (!Array.isArray(meetups)) {
    console.log(`  Skipping: videos.yml is not an array`)
    return { created: 0, skipped: 1 }
  }

  const results = { created: 0, skipped: 0 }

  // Process each meetup entry
  for (const meetupEntry of meetups) {
    const date = meetupEntry.date
    if (!date) {
      console.log(`  Skipping entry: no valid date - ${meetupEntry.title}`)
      results.skipped++
      continue
    }

    const title = meetupEntry.title || meetupEntry.event_name
    const slug = generateSlug(title)
    const yearMonth = extractYearMonth(date)

    // Prefix with YYYY-MM- for chronological sorting
    const folderName = yearMonth ? `${yearMonth}-${slug}` : slug
    const newFolderPath = path.join(seriesPath, folderName)

    // Check if folder already exists
    let finalFolderPath = newFolderPath
    let suffix = 1
    while (fs.existsSync(finalFolderPath) && !CONFIG.dryRun) {
      suffix++
      finalFolderPath = path.join(seriesPath, `${folderName}-${suffix}`)
    }

    const finalFolderName = suffix > 1 ? `${folderName}-${suffix}` : folderName

    // Generate event.yml (id matches folder name for Rails compatibility)
    const eventYml = generateEventYml(meetupEntry, originalEvent, finalFolderName)

    // Transform talks to videos
    const videos = transformTalks(meetupEntry, slug)

    if (CONFIG.verbose || CONFIG.dryRun) {
      console.log(`  ${CONFIG.dryRun ? '[DRY RUN] Would create' : 'Creating'}: ${finalFolderName}/`)
      console.log(`    - event.yml (id: ${eventYml.id})`)
      console.log(`    - videos.yml (${videos.length} talks)`)
    }

    if (!CONFIG.dryRun) {
      // Create folder
      fs.mkdirSync(finalFolderPath, { recursive: true })

      // Write event.yml
      const eventYmlContent = toYaml(eventYml)
      fs.writeFileSync(path.join(finalFolderPath, 'event.yml'), eventYmlContent)

      // Write videos.yml
      const videosYmlContent = toYaml(videos, { spaceBetweenItems: true })
      fs.writeFileSync(path.join(finalFolderPath, 'videos.yml'), videosYmlContent)
    }

    results.created++
  }

  // Rename original folder to .bak
  const bakPath = `${meetupPath}.bak`
  if (!CONFIG.dryRun && results.created > 0) {
    if (fs.existsSync(bakPath)) {
      console.log(`  Warning: ${bakPath} already exists, not renaming original`)
    } else {
      fs.renameSync(meetupPath, bakPath)
      console.log(`  Renamed original to: ${meetupSlug}.bak`)
    }
  } else if (CONFIG.dryRun && results.created > 0) {
    console.log(`  [DRY RUN] Would rename: ${meetupSlug} → ${meetupSlug}.bak`)
  }

  return results
}

/**
 * Main function
 */
function main() {
  console.log('='.repeat(60))
  console.log('Meetup Migration Script')
  console.log('='.repeat(60))
  console.log(`Mode: ${CONFIG.dryRun ? 'DRY RUN' : 'LIVE'}`)
  if (CONFIG.seriesFilter) {
    console.log(`Series filter: ${CONFIG.seriesFilter}`)
  }

  const meetups = findMeetupFolders()
  console.log(`\nFound ${meetups.length} meetup folder(s) to process`)

  const totals = { created: 0, skipped: 0 }

  for (const meetup of meetups) {
    const results = processMeetup(meetup)
    totals.created += results.created
    totals.skipped += results.skipped
  }

  console.log('\n' + '='.repeat(60))
  console.log('Summary')
  console.log('='.repeat(60))
  console.log(`Event folders created: ${totals.created}`)
  console.log(`Entries skipped: ${totals.skipped}`)

  if (CONFIG.dryRun) {
    console.log('\nThis was a dry run. No changes were made.')
    console.log('Run without --dry-run to apply changes.')
  } else if (totals.created > 0) {
    console.log('\nNext steps:')
    console.log('1. Run `bin/rails db:seed` to reload data')
    console.log('2. Verify data loads correctly')
    console.log('3. Delete .bak folders when confirmed working')
  }
}

main()
