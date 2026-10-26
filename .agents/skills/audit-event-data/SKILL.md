---
name: audit-event-data
description: Verify that data/{series}/{event}/ matches the event's official website and report discrepancies without changing anything. Use when asked to check, audit, reconcile, verify, or compare conference data against a site, agenda, or schedule — including "are there any discrepancies between X and their website?".
---

# Auditing event data against the source of truth

This skill **finds and reports** differences between `data/{series}/{event}/` and
the event's own website. It is the read-only counterpart to `backfill-event-data`.

Stop at the report. Do not edit data files, do not create a branch, do not commit —
unless the user asks for the fixes in the same request. If they later ask, switch to
`backfill-event-data` for the mechanics and keep the verification steps below.

## The contract

**Report, don't fix.** A clean audit that finds 10 discrepancies and applies 0 is a
success. Editing mid-audit means the user can no longer see what was wrong.

**Never invent a value.** If the site doesn't say something, the answer is "Not present on the source (checked: {urls})", not a plausible guess. This is a historical record; a confident wrong
value is worse than a blank.

**Cite both sides.** For every item in review, show the data side (`data/{path}:{line}` with a short excerpt) and the source side (exact URL, section/selector, and a direct quote). If multiple sources are checked, list them all.

**Don't reconcile.** Do not recommend which value to keep or which source to trust. If sources conflict with each other (e.g. homepage vs agenda vs registration vs JSON-LD), list the conflict and ask the reviewer which one to trust.

**Distinguish *our* bug from *their* inconsistency.** Sites contradict themselves. Surface contradictions as conflicts and leave the decision to the reviewer.

## Workflow

### 1. Establish scope

- `event_lookup` with the event name to get the slug, dates, and `data_path`.
- Read every file in `data_path` (`event.yml`, `videos.yml`, `schedule.yml`,
  `sponsors.yml`, `venue.yml`, `involvements.yml`, `cfp.yml`).
- Note anything the files assert that you must go verify.
- Run `git status` early. Pre-existing unrelated edits are the user's work — leave them alone.

### 2. Gather the source of truth

Fetch the site and **every subpage that carries structured data**, not just the
homepage. Discover them rather than guessing:

| Data | Where it's usually hiding |
|---|---|
| Dates, location | homepage, `<title>`, meta description, JSON-LD `Event` block |
| Agenda / times | `/agenda`, `/program`, `/schedule` |
| Speakers | homepage speaker strip, `/speakers`, `/speaker-*.html` detail pages |
| Talk details | **Detail/session pages for each talk** (e.g. `/sessions/<slug>`, `/talks/<slug>`). Fetch these — program listings are often condensed. Extract descriptions and speaker socials from them. |
| Venue & hotels | homepage venue section, `/venue`, `/accommodation` |
| Sponsors | homepage, `/sponsors` — logos link out to the sponsor's site |
| Organizers | homepage, `/team`, `/organizers` — capture role labels in the site's language as-is |
| CFP | homepage badge, `/cfp` — the CFP host is often a *different domain* |
| Series | Umbrella/series site and `series.yml`. Check frequency and other series-level metadata. |

**Read JSON-LD.** A `<script type="application/ld+json">` block is a structured,
authoritative summary. Cite it if used.

**Peek inside agenda embeds.** Some sites delegate the agenda to a SaaS (Sessionize,
Swapcard, Brella); the iframe renders little server-side. If the static page is too
thin, the iframe's `src` and its embedded JSON usually carry the real schedule.

**Cross-check the series site.** The umbrella site (`https://{series}.org` or equivalent) usually has
a year-by-year table with authoritative dates and metadata (e.g. frequency). Compare `series.yml` against it.

**Check the video channel** for published recordings, via `series.yml` →
`youtube_channels` → `youtube_channel_playlists`. If the event is over but there is no
playlist yet, `video_provider: "scheduled"` is still correct — say so in context, don't treat it as a discrepancy.

**Be locale-agnostic.** Look for structural patterns (time ranges, speaker grids/lists, role labels next to names, sections) rather than specific keywords in any one language.

### 3. Compare, systematically

Walk each file against what you gathered. For each, note **file:line** so the user can
jump straight to it.

- **event.yml** — dates, location string, description wording, `year`, `frequency`, `venue`,
  `tickets_url`. Cross-check dates against *two* sources before calling
  a mismatch: a site may headline the conference days while a pre-day meetup or a
  post-day excursion sits outside that window. Event dates may match conference days only
  or include pre and post days. If a link is provided to buy tickets, we want to add it.
- **series.yml** — `frequency` and other metadata vs the series/umbrella site.
- **schedule.yml** — every `start_time`/`end_time`, item titles and descriptions, day boundaries, **and anything present in the source but absent here**. Slots without items are filled by talks from videos.yml in order.
- **videos.yml** — talk titles (verbatim), kinds, dates, start/end time, speaker lists, running order, descriptions/summaries (check session detail pages), and every talk on the site that's missing here.
- **cfp.yml** — call for papers open date, close date, and link. **Often, the cfp link is removed once it closes.** If the open/close data cannot be confirmed, trust the file as the authoritative source. Do not raise missing open/close dates or broken cfp links as discrepancies. Only raise them if there is a conflict.
- **venue.yml** — venue name, address, hotels, distances, ratings.
- **sponsors.yml** — tiers, membership, names, ordering, badges/grouping as presented.
- **involvements.yml** — names and role labels against the organizers/team page (preserve site language).
- **speakers.yml** (contextual) — only when referenced by discrepancies (e.g. socials on session pages). Don't rewrite speaker identities; surface conflicts for review.

### 4. Report

Structure the report as follows:

#### Overview
- Event/series, dates, `data_path`
- Sources fetched (list each URL/subpage: homepage, program/schedule, speakers, each session detail page, team, sponsors, venue, series page, JSON-LD if used)
- Files read
- Count of items for review

#### Confirmed correct
Brief list of things explicitly verified against a source. For each, cite the source URL/section that confirmed it.

#### Items for review
For **every** discrepancy, conflict, missing data, or unclear item, create a separate entry with this format:

- **Category**: `event` | `series` | `schedule` | `videos` | `speakers` | `sponsors` | `involvements` | `venue` | `cfp` | `other`
- **Data side**: `data/{path}:{line}` (or range) + a short excerpt of what we have
- **Source side**: Exact URL(s) checked, section/selector, and a **direct quote** of what the source says. If multiple sources disagree, list each with its own quote.
- **Type**: `missing` | `differs` | `conflicts` | `unclear`
- **Question**: A question for the reviewer to answer (e.g. "Keep our value or change to match the session page at {url}?").
- **Notes**: Context only (e.g. "referenced by videos.yml as alias `misamisa`", "validator would block if changed", "site has no summary", "JSON-LD also checked").

**Note: If there are no discrepancies, state "No discrepancies found."**

#### Not our problem
Things the source omits or where the site is internally inconsistent with no clear authoritative source to ask about — just state what's missing/conflicting with URLs checked.

**Rules for this section:**
- If something isn't present on any checked source, say "Not present on the source (checked: {urls})".
- If sources conflict, set type `conflicts`, list both sides with quotes, and ask which one to trust.
- Don't rank or prioritize fixes. Just present items for review.
- Don't offer to apply changes in this report unless the user explicitly asked for fixes in the same request.

### 5. Verify (only when fixes were requested)

Re-run the whole chain after editing — a schedule edit can silently break talk mapping.

```bash
bin/rails validate:all                                     # every validator
```

**The talk-mapping script must be slot-aware.** A grid row with `slots: 6` and no
`items` consumes **six** talks, not one. A naive one-talk-per-row script reports false
mismatches and erodes trust in the whole audit. Per row, walk
`(slots - items.length).times`, pulling talks from `videos.yml` in file order, and
assert each talk's `date` matches the day's `date`; print the final `filled N/total`
and any leftovers. If `filled` is short, a row's `slots` no longer matches the talk
count — usually caused by an added `items` row adjacent to talk rows.

Two structural limits to know before recommending a schedule edit:

- The grid is **sequential rows**. Two genuinely overlapping items cannot be expressed as parallel columns. Don't silently fudge times.
- **Title/id changes**: changing titles can affect `Talk::StaticID` in edge cases (speakerless or 3+-speaker talks with kind inferred as `"talk"`). Renaming/dropping ids may need `old_id:` or `removed_talk_ids:` in `event.yml`. Only worry about this if fixes are requested.

## Traps

- **Homepage copy is simplified marketing.** A speaker strip may shows highlights, not the full roster. Missing entries there aren't missing from the event — confirm against the full agenda or detail pages before listing as an item.
- **The same event's homepage can contradict its own agenda.** Both are "official". Report as a conflict with both quotes and ask which to trust.
- **Dead subdomains are common post-event.** A CFP host that no longer resolves is a real finding, but you cannot verify the CFP dates. Say "Not present on the source (checked: {urls})" / note resolution failure.
- **`country` naming varies** between sites — if it differs cosmetically, treat as `unclear` or note under Not our problem without pressuring a change.
- **Don't compare against a stale cached page** when the site is live.
- **`.description` blocks carry the real content.** Read them in full; titles alone hide discrepancies.
- **Check `git status` early.** Pre-existing unrelated edits are the user's work — leave them alone.
- **Cite sources.** Every item for review must include both sides with URLs/quotes.
- **No automatic reconciliation.** The skill's job is to ask questions, not to decide.
