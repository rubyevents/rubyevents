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

**Never invent a value.** If the site doesn't say something, the answer is "the site
doesn't say", not a plausible guess. This is a historical record; a confident wrong
value is worse than a blank.

**Distinguish "differs" from "wrong".** Some differences are correct decisions we
made deliberately. Say so, and let the user decide. Frame findings as *source says X,
we say Y* — not *X is wrong*.

**Distinguish *our* bug from *their* inconsistency.** Sites contradict themselves. When
two official sources disagree (e.g. a homepage blurb vs. the embedded agenda), surface
the conflict and recommend which to trust — don't silently pick one.

## Workflow

### 1. Establish scope

- `event_lookup` with the event name to get the slug, dates, and `data_path`.
- Read every file in `data_path` (`event.yml`, `videos.yml`, `schedule.yml`,
  `sponsors.yml`, `venue.yml`, `involvements.yml`, `cfp.yml`).
- Note anything the files assert that you must go verify.

### 2. Gather the source of truth

Fetch the site and **every subpage that carries structured data**, not just the
homepage. Discover them rather than guessing:

| Data | Where it's usually hiding |
|---|---|
| Dates, location | homepage, `<title>`, meta description, JSON-LD `Event` block |
| Agenda / times | `/agenda`, `/program`, `/schedule` |
| Speakers | homepage speaker strip, `/speakers`, `/speaker-*.html` detail pages |
| Venue & hotels | homepage venue section, `/venue`, `/accommodation` |
| Sponsors | homepage, `/sponsors` — logos link out to the sponsor's site |
| Organizers | homepage, `/team`, `/organizers` |
| CFP | homepage badge, `/cfp` — the CFP host is often a *different domain* |

**Read JSON-LD.** A `<script type="application/ld+json">` block is a structured,
authoritative summary. It resolves headline ambiguity in the visible copy.

**Peek inside agenda embeds.** Some sites delegate the agenda to a SaaS (Sessionize,
Swapcard, Brella); the iframe renders little server-side. If the static page is too
thin, the iframe's `src` and its embedded JSON usually carry the real schedule.

**Cross-check the series site.** The umbrella site (`https://{series}.org`) usually has
a year-by-year table with authoritative dates, and links to each edition. It is the tiebreaker when an edition site is vague or post-event.

**Check the video channel** for published recordings, via `series.yml` →
`youtube_channels` → `youtube_channel_playlists`. If the event is over but there is no
playlist yet, `video_provider: "scheduled"` is still correct — say so rather than
flagging it.

### 3. Compare, systematically

Walk each file against what you gathered. For each, note **file:line** so the user can
jump straight to it.

- **event.yml** — dates, location string, description wording and typos, `venue`,
  `tickets_url`, brand colors. Cross-check dates against *two* sources before calling
  a mismatch: a site may headline the conference days while a pre-day meetup or a
  post-day excursion sits outside that window. Ours intentionally covers the whole
  bracketed period; see `docs/ADDING_EVENTS.md`.
- **schedule.yml** — every `start_time`/`end_time`, item titles and descriptions,
  day boundaries, **and anything present in the source but absent here**.
- **videos.yml** — talk titles (verbatim), kinds, dates, speaker lists, running order,
  and every talk on the site that's missing here.
- **venue.yml** — venue name, address, hotels, distances, ratings.
- **sponsors.yml** — tiers, membership, names, ordering.
- **involvements.yml** — names against the organizers page.

Rank findings by confidence and consequence. Put real errors first; park deliberate
exclusions and cosmetic naming last, clearly labelled so they can be dismissed in one
pass.

### 4. Report

Group as: **Confirmed correct** (brief — it proves you checked), **Discrepancies**
(numbered, each with source-vs-ours, file:line, and your confidence), **Not our problem**
(things the source omits or contradicts itself). Offer to fix, and note which ones need
a human call because the sources disagree.

### 5. Verify (only when fixes were requested)

Re-run the whole chain after editing — a schedule edit can silently break talk mapping.

```bash
bundle exec yerba check                                    # formatting; runs in CI
bin/rails validate:all                                     # every validator
bin/rails runner <slot-aware mapping script>               # see below
```

**The talk-mapping script must be slot-aware.** A grid row with `slots: 6` and no
`items` consumes **six** talks, not one. A naive one-talk-per-row script reports false
mismatches and erodes trust in the whole audit. Per row, walk
`(slots - items.length).times`, pulling talks from `videos.yml` in file order, and
assert each talk's `date` matches the day's `date`; print the final `filled N/total`
and any leftovers. If `filled` is short, a row's `slots` no longer matches the talk
count — usually caused by an added `items` row adjacent to talk rows.

Two structural limits to know before recommending a schedule edit:

- The grid is **sequential rows**. Two genuinely overlapping items (A 19:50–20:10,
  B 19:50–20:20) cannot be expressed as parallel columns. Add B as its own row and
  *say* it overlaps, or reshape the grid — don't silently fudge times.
- **Most title edits are safe, but not all.** `Talk::StaticID#speaker_id` resolves in
  this order: one or two speakers → slugified speaker names; else a non-`talk` kind →
  slugified kind; else → slugified **title**. So a title change leaves the id untouched
  for speaker-attributed talks, for lightning talks (`kind: lightning_talk`), and for
  panels — all verified against `app/models/talk/static_id.rb`. It **only** changes the
  id for a speakerless or 3+-speaker talk whose kind resolves to `"talk"` (explicit, or
  inferred from the title). Those need `old_id:`. When unsure, check the branch rather
  than assuming.
- Renaming or dropping an **id** always needs migration: `old_id:` on the renamed entry,
  or the id under `removed_talk_ids:` in the sibling `event.yml`. `bin/rails
  talk_ids:backfill_old_ids` writes `old_id` for you.

## Traps

- **Homepage copy is simplified marketing.** A speaker strip shows highlights, not the
  roster. Missing entries there aren't missing from the event — confirm against the
  full agenda or speakers page before calling it a discrepancy.
- **The same event's homepage can contradict its own agenda.** Both are "official".
  Report the conflict; prefer the structured agenda.
- **Dead subdomains are common post-event.** A CFP host that no longer resolves is a
  real finding, but you cannot verify the CFP dates. Say that instead of guessing.
- **`country` naming varies** ("Czechia" vs "Czech Republic") between sites and is
  usually not worth changing. Flag as cosmetic, at the bottom.
- **Don't compare against a stale cached page** when the site is live.
- **`.description` blocks carry the real content.** Read them in full; titles alone
  hide discrepancies like a talk having *three* short talks rather than none.
- **Check `git status` early.** Pre-existing unrelated edits are the user's work — leave
  them alone and keep them out of any commit.