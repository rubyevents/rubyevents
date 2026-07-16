---
name: backfill-event-data
description: |-
  Add or backfill RubyEvents conference data for an event from its website — involvements (organizers/MCs), sponsors, venue + hotels, schedule, talk running order, and speaker GitHub/Twitter handles. Use whenever editing files under data/{series}/{event}/ (involvements.yml, sponsors.yml, venue.yml, schedule.yml, videos.yml) or reconciling speaker social handles in data/speakers.yml.
---

# Backfilling conference event data

How to add/fix event data in this repo the way it actually works. Field-level doc live in `docs/ADDING_*.md` (INVOLVEMENTS, SPONSORS, VENUES, SCHEDULES, VIDEOS, …) an schemas in `app/schemas/*.rb` — read those for field lists. This skill is th **operating procedure**: the hooks, the tools, and the non-obvious gotchas.

## Hard rules (enforced by hooks in `.claude/settings.json`)

1. **Never `Write`/`Edit` a file under `data/`.** A PreToolUse hook blocks it. Create and edit data files with the **generators** (`bin/rails g …`) and **yerba** (CLI or the Yerba Ruby API via `bin/rails runner`). `sed`/`awk` on data files are *not* blocked (the hook only guards the Write/Edit tools) and are fine for surgical text fixes (e.g. quoting, deleting a header line) — always follow with `yerba check`.
2. **Never `YAML.load_file` / `YAML.dump` / `.to_yaml`** in a Bash/runner command — a hook blocks it. Read data with `Yerba.parse_file`, write with `doc.save!`.
3. **Never edit `lib/schemas/*.json`** — auto-generated. Edit `app/schemas/*.rb` then `bin/rails schema:export`.
4. Finish every change with `bundle exec yerba check <files>` (this is what CI runs). Don't commit unless asked.

## Data layout

```
data/{series-slug}/{event-slug}/
  event.yml  videos.yml  involvements.yml  sponsors.yml  venue.yml  schedule.yml
data/speakers.yml          # global, one entry per speaker
```

## Tooling

### Generators (`bin/rails g <name> --help` for each)

`involvements`, `sponsors`, `venue`, `schedule`, `event`, `cfp`, `talk`, `newsletter`. They write via yerba and validate. Quirks that bite:
- **sponsors**: args are pipe-separated `"Name|url|Tier|badge"`, `--event-series --event`. The template **ignores the url and hardcodes placeholder `website`/`logo_url`** — you must fill real values afterward (`yerba set`). Tiers get `level` 1,2,3… in first-seen order, so list all Gold, then all Silver, etc.
- **venue**: `--name --address` (address is **geocoded**); flags `--hotels/--locations/ --rooms/--spaces/--accessibility/--nearby` add **one placeholder** section each. It **also overwrites `event.yml` coordinates** with the geocoded venue coords. Geocoding by *name* can resolve the wrong place (e.g. wrong campus) — verify and fix with the `geocode` MCP tool + `yerba set`.
- **schedule**: auto-fills the talk *count* from videos.yml into a **uniform** grid you then rewrite to the real program (see Schedule below).
- Generators leave a `# docs/ADDING_*.md` / `# TODO:` header. Convention is files start at `---`; delete the header lines (sed) once the file is real, then `yerba check`.

### yerba CLI
- `yerba get FILE "selector" [--condition ".k == v"] [--select ".a,.b"]`
- `yerba set FILE "selector" value` — **quotes numeric-looking strings correctly**. Indexed selectors work: `[0].tiers[1].sponsors[2].website`. Note: a `set` runs the Yerbafile and **aborts the write if the file has any validation error elsewhere**, so fix all blockers together (or use sed) rather than one-at-a-time.
- `yerba move FILE "" ".id == X" --after ".id == Y"` — reorder a sequence item. Most reliable way to reorder a few entries.
- `yerba sort FILE "[]" --by ".id" --order "a,b,c"` — explicit order (but `--by` can choke when nested children share the key name; prefer `move` for a handful of items).
- `yerba apply FILE` — reformat to Yerbafile rules (blank lines, key order, sorts `speakers.yml` by name). Run after edits.
- `yerba check FILE` — schema + formatting validation.
- Conditional selectors in `get`/`set` (`[.name == "X"]`) are unreliable — prefer `--condition` for reads and indexed/Ruby edits for writes.

### yerba Ruby API (`bin/rails runner script.rb`; `Yerba` is autoloaded)

Use this to build nested structures (hotels, schedule days, new speakers) that are painful via CLI.

```ruby
document = Yerba.parse_file("data/…/venue.yml")

document["description"]          = "…"            # scalar / dotted path on a MAP root
document["address.postal_code"]  = "14482"        # OK for existing scalar keys
document["hotels"]               = [ {...}, ... ] # OK for a NEW key on a map root

node = document.root.find { |s| s["slug"].value == "luis-ferreira" }  # sequence root

node["aliases"] = [{"name" => "Luis Ferreira", "slug" => "luis-ferreira"}]

document.root << {"name" => "…", "github" => "", "twitter" => "…", "slug" => "…"} # append
document.save!                    # write; use save!(apply: true) to also validate/format
```

Gotchas:
- Replacing an **existing** complex key or setting a key on a **sequence** root via `doc["key"]=` fails ("selector not found" / "root is a Sequence"). For a full rewrite do `doc.root = {}` first; to add to a child use `node["k"]=`; to append use `doc.root << h`.
- The Ruby API writes **numeric-looking strings unquoted** (postal codes, `"09:45"`) → schema validation rejects them as integers. So `doc.save!` (no apply), then quote the offending lines with `yerba set`/sed, then `yerba apply`. Empty-string values may serialize as `null` and fail `required` checks — **omit optional keys** instead of `""`.

### MCP tools (`mcp__rubyevents__*`) — allowed without prompt

- `geocode(location)` — venue & hotel coordinates/address. Pass a **precise street address**, not just a venue name.
- `github_profile(username)` / `github_search(query, language?)` — find & **verify** handles. **Always confirm by matching the profile's `name` to the speaker.** A twitter handle often equals the github one but not always, and the data contains wrong-person values (e.g. a handle that actually belongs to someone else).
- `youtube_*`, `vimeo_video`, `speakerdeck_*` — media metadata.
- `speaker_lookup/create/update/add_alias`, `event_*`, `venue_create` — DB helpers, but the **YAML is the source of truth** (DB is seeded from it); prefer editing the files.

### Scraping the conference site

- Prefer `npx agent-browser` (`open` / `eval` / `snapshot -i` / `close`) — it's allow-listed. `WebFetch(domain:github.com)` and general WebFetch work as a fallback but can't reliably grab per-element social links.
- Speaker/team names are usually **CSS-uppercased** — extract by DOM order (walk text + `<a href>` in document order and group), not by matching all-caps text.

## Recipes

### involvements.yml

`bin/rails g involvements --event <slug> --name "Organizer" --users "A" "B" --organisations "Org"`. Run once per role (Organizer, MC, Volunteer, Program Committee, Video Production, …); role names are singularized and the singular form is convention. Users don't need to pre-exist (seeding auto-creates bare Users) — but to give them social handles, add speaker entries.

### sponsors.yml

Generate the tier skeleton, then `yerba set` each sponsor's real `website` and `logo_url` (the generator only writes placeholders). Level order = tier order in the args.

### venue.yml + hotels

Generate with `--name --address`; then correct the geocode if it missed, add `maps`, and build the `hotels` array with the Ruby API (one placeholder from `--hotels` isn't enough for several hotels). `geocode` each hotel. Quote postal codes. Re-check `event.yml` coordinates the generator may have changed.

### schedule.yml  ← depends on videos.yml order

- Grid entries **with** an `items:` list render as fixed items (Registration, Break, Lunch, Closing…). Entries **without** `items:` are **talk slots** that auto-fill **sequentially from `videos.yml` entry order** (`talks_in_running_order`, child_talks false → a lightning-talks parent counts as **one** slot).
- Therefore **`videos.yml` must be in chronological running order**, and the number of empty slots per day must equal that day's talk count. If videos.yml isn't in running order (it's often in upload order), reorder with `yerba move` **before** trusting the schedule.
- Build days via the Ruby API (`doc.root = {}; doc["days"] = [...]; doc["tracks"] = []`), then quote all `start_time`/`end_time`/`date` values (sed), then `yerba apply`.
- **Verify the mapping** with a runner that pairs each empty slot to the next talk:

```ruby
schedule = Yerba.parse_file("data/…/schedule.yml")
videos = Yerba.parse_file("data/…/videos.yml")
titles = videos.root.map { |t| [t["id"].value, t["title"].value] }
i = 0

schedule["days"].each do |day|
  day["grid"].each do |s|
    if s.keys.include?("items")
      puts "  item"
    else
      id, t = titles[i]
      puts "  #{s["start_time"].value} -> #{t}"
      i += 1
    end
  end
end

puts "filled #{i}/#{titles.size}"
```

### videos.yml (talk order / "check the talks")

Compare titles/speakers/order against the site's schedule & speakers pages. Reorder to true running order with `yerba move ... --after ...`. A clean block move shows equal insertions/deletions in `git diff --stat` and preserves block scalars. Note `published_at` stays in upload order — it's the **entry order** that drives running order.

### speaker social handles (data/speakers.yml)

- Global, flat sequence, auto-sorted by name; enforced key order: `name, github, twitter, mastodon, bluesky, linkedin, website, speakerdeck, slug, aliases`. **Required: name, slug, github** (`github: ""` if unknown).
- Add new speakers by appending (`doc.root << {name, github, twitter?, slug}`) then `yerba apply` (sorts + orders keys). Patch existing by setting the field on the node (or targeted awk on the `github:`/`twitter:` line following the matched `name:`).
- **Renamed speakers use canonical merge**: the *current* name is the top-level entry and old names are `aliases: [{name, slug}]`. If a talk speaker's handles look "missing", check whether that name is an alias of a current-name entry and patch the **canonical** entry (its handles are usually already current and correct — don't downgrade them to a stale value from the site).
- Verify every handle with `github_profile` (match `.name`). Watch for: twitter≠github, wrong-person handles already in the data, and site links that are stale for renamed people.

## End-to-end order of operations

1. Scrape the site (agent-browser): MCs, team/organizers, sponsors+logos, venue+hotels, schedule, speakers + social links, talk abstracts.
2. `geocode` venue and hotels.
3. Generate + fill: involvements → sponsors → venue(+hotels) → schedule.
4. Reconcile `videos.yml` order to the running order; verify the schedule mapping.
5. Reconcile `speakers.yml` github/twitter for every talk speaker (verify via `github_profile`); add missing speaker/organizer entries.
6. `bundle exec yerba check` all touched files. Report; commit only if asked.
