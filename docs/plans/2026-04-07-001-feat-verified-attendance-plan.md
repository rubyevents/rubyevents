---
title: "feat: Add verified attendance via passport scan CSV import"
type: feat
status: active
date: 2026-04-07
origin: docs/brainstorms/2026-04-07-verified-attendance-requirements.md
deepened: 2026-04-07
---

# feat: Add verified attendance via passport scan CSV import

## Overview

Add the ability to import event attendance data from the Ruby Passport scanning app (CSV) into RubyEvents.org. Records are stored by passport `connect_id`, resolved to users at read time through `ConnectedAccount`, and surfaced as a "Verified" badge on profile event listings, a count on event pages, and as input to the passport stamp system.

## Problem Frame

Event organizers scan attendee QR codes at conferences. This data proves physical attendance but has no path into RubyEvents.org today. Self-reported attendance (EventParticipation) is the only mechanism, and there's no way to distinguish "I clicked a button" from "I was physically there." (see origin: docs/brainstorms/2026-04-07-verified-attendance-requirements.md)

## Requirements Trace

- R1. VerifiedEventParticipation model keyed by connect_id + event_id with scan timestamp
- R2. Unique composite index, deduplication on import, idempotent re-imports
- R3. Stored by connect_id, resolved to user at read time via ConnectedAccount; handles multiple passports per user
- R4. Avo action: admin selects Event, uploads CSV, imports records
- R5. Import reports created/skipped/errored counts; row-by-row partial success
- R6. Profile events page: unified list merging self-reported + verified sources
- R7. Verified badge on events with verified attendance (three states)
- R8. Event pages show verified attendee count
- R9. Verified attendance feeds into stamp system
- R10. connect_id uppercased on import

## Scope Boundaries

- CSV import only — no real-time sync or API endpoint
- No changes to EventParticipation model
- No user-facing UI for claiming/disputing verified attendance
- A user can have both self-reported and verified attendance for the same event

## Context & Research

### Relevant Code and Patterns

- **EventParticipation** (`app/models/event_participation.rb`) — closest model analog: schema annotation, belongs_to associations, uniqueness validation with scope, enum
- **ConnectedAccount** (`app/models/connected_account.rb`) — passport provider enum, `normalizes :username` pattern for string fields, unique index on `[provider, uid]`. **Note:** `uid` is NOT normalized — stored as-is from the claim flow. This is a data integrity risk for case-sensitive joins.
- **User#passports** (`app/models/user.rb:96`) — `has_many :passports, -> { passport }, class_name: "ConnectedAccount"` gives direct access to passport connect_ids
- **Avo actions** (`app/avo/actions/assign_canonical_speaker.rb`) — pattern: select field with lambda options, `handle` with query iteration, `succeed` message
- **Profile events controller** (`app/controllers/profiles/events_controller.rb`) — queries `@user.participated_events`, builds `@participations` hash keyed by event_id
- **ProfilesController#show** (`app/controllers/profiles_controller.rb`) — also renders `_events` partial with its own `@events` and `@participations` data. Both controllers must be updated.
- **ProfileData concern** (`app/controllers/concerns/profile_data.rb`) — `load_common_data` sets `@events = @user.participated_events` used for `@events_with_stickers` and `@countries_with_events` across all profile tabs
- **Profile events partial** (`app/views/profiles/_events.html.erb`) — splits events into future/past (not year grouping), passes `participation:` to event card, uses fragment caching
- **Event card** (`app/views/events/_card.html.erb`) — shows `ui_badge(participation.attended_as.humanize)` when participation present
- **Event show** (`app/views/events/show.html.erb:24-25`) — displays `@event.participants.count` as "Known Participants" (only for retreat-type events; non-retreats show Talks/Speakers/Sponsors)
- **Event card** (`app/views/events/_card.html.erb:1`) — declares locals with `<%# locals: (event:, participation: nil) %>`. Must be updated to accept `verified:` parameter. Card is rendered from multiple callers (profile events, home page, browse page).
- **Stamp.for_user** (`app/models/stamp.rb:90-126`) — calls `user.participated_events` at 4 distinct call sites (lines ~91, ~141, ~154, ~159) for country stamps, event stamps, triathlon check, conference check, online check
- **Migration pattern** — most recent migrations use `ActiveRecord::Migration[8.2]` (e.g., `db/migrate/20260306110802_add_level_to_sponsors.rb`)

### Institutional Learnings

No `docs/solutions/` directory exists — no prior learnings to carry forward.

## Key Technical Decisions

- **No user_id on VerifiedEventParticipation**: The model stores `connect_id` (string) + `event_id` (FK). User resolution happens at read time via `ConnectedAccount.where(provider: "passport", uid: connect_ids)`. This keeps import completely decoupled from user registration (see origin).

- **`User#verified_attended_events` as a separate method**: Rather than replacing `participated_events` everywhere, add a new method that returns events linked through verified attendance. Only the Stamp model and profile events page need the merged view. This limits blast radius — the 15+ call sites using `participated_events` are untouched unless they specifically need verified data.

- **Stamp integration via `User#all_attended_events`**: A convenience method that plucks IDs from both `participated_events` and `verified_attended_events`, deduplicates, and returns `Event.where(id: ...)`. Used only in `Stamp.for_user`. Array-based approach preferred over `.or()` — simpler, no structural compatibility concerns with Rails/SQLite, and adequate at this data scale (< 200 events per user).

- **Profile events: query-then-merge in controller**: Keep the existing `participated_events` query and add a second query for verified-only events (events with verified attendance but no self-reported participation). Merge into one `@events` collection. Pass `@verified_event_ids` (a Set) to the view for badge rendering. This preserves the existing view pattern of passing `participation:` to the card.

- **Event page: live count, no cache**: Verified attendee counts are small (< 200 per event) and the query is a simple join. No counter cache or fragment cache needed initially — SQLite handles this fine.

- **Avo action on Event resource**: The import action is attached to the Event resource (not standalone) so the admin navigates to the event first, then runs the action. This avoids needing an event selector field — the event is the selected record. Action must validate exactly one event is selected.

- **Normalize ConnectedAccount.uid**: Add `normalizes :uid, with: ->(v) { v.strip.upcase }` to ConnectedAccount to ensure case-insensitive matching with VerifiedEventParticipation.connect_id. Without this, the read-time join silently fails for any passport claimed with lowercase uid. Includes a data migration to upcase existing passport uid values.

- **Scope boundary for `participated_events` replacement**: Only `Stamp.for_user` and the profile events page adopt `all_attended_events`. Other call sites (`set_mutual_events`, wrapped, map, stickers, browse) intentionally remain on `participated_events`. These can be expanded later if verified attendance should affect those features.

## Open Questions

### Resolved During Planning

- **Event page display format (from origin)**: Show a "Verified Attendees" count next to the existing "Known Participants" count on the event show page. Keep it simple — count only, no avatar list. This mirrors the existing participant count pattern.

- **Unified query approach (from origin)**: Use two separate queries in the profile events controller — one for participated_events (existing) and one for verified-only events. Merge in Ruby, pass `@verified_event_ids` set to view. Avoids complex SQL union while preserving existing view patterns.

- **Stamp integration approach (from origin)**: Add `User#all_attended_events` returning `Event.where(id: union_of_both_sources)`. Replace `user.participated_events` with `user.all_attended_events` only in `Stamp.for_user` (5 call sites). Other call sites remain unchanged.

- **Avo action placement (from origin)**: Attach to Event resource, not standalone. Admin selects event record, runs "Import Verified Event Participation" action, uploads CSV.

### Deferred to Implementation

- Exact CSV parsing error handling edge cases (encoding, BOM) — handle as errors in the row-by-row processing
- Whether verified attendee count on event page should appear for all event types or only certain kinds — decide based on the event show page layout during implementation

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
Data flow:

CSV row (connect_id, event, scan_type, created_at)
  → uppercase connect_id
  → find_or_initialize VerifiedEventParticipation(connect_id, event_id)
  → skip if exists, create if new, count error if invalid

Read-time resolution:

User → passports (ConnectedAccount where provider=passport)
     → pluck(:uid) → ["757D1E", "73CA67", ...]
     → VerifiedEventParticipation.where(connect_id: uids)
     → .pluck(:event_id) → Event.where(id: ids)

Profile unified list:

  participated_events (existing query, unchanged)
  + verified_only_events (events with VA but no EP)
  = merged @events, with @verified_event_ids Set for badge

Stamp integration:

  User#all_attended_events
    = Event.where(id: participated_event_ids + verified_event_ids)
    → replaces user.participated_events in Stamp.for_user only
```

## Implementation Units

- [ ] **Unit 1: VerifiedEventParticipation model, migration, and ConnectedAccount uid normalization**

  **Goal:** Create the database table and model for storing verified attendance records. Also normalize ConnectedAccount.uid to ensure reliable joins.

  **Requirements:** R1, R2, R3, R10

  **Dependencies:** None

  **Files:**
  - Create: `db/migrate/YYYYMMDDHHMMSS_create_verified_event_participations.rb`
  - Create: `db/migrate/YYYYMMDDHHMMSS_normalize_connected_account_uids.rb`
  - Create: `app/models/verified_event_participation.rb`
  - Modify: `app/models/connected_account.rb`
  - Modify: `app/controllers/profiles/connect_controller.rb` (upcase `@connect_id`)
  - Create: `test/models/verified_event_participation_test.rb`

  **Approach:**
  - Migration creates `verified_event_participations` table with `connect_id` (string, not null), `event_id` (references, not null, FK), `scanned_at` (datetime, not null), timestamps. Use `ActiveRecord::Migration[8.2]`.
  - Unique composite index on `[connect_id, event_id]`
  - Index on `connect_id` for read-time lookups
  - Model: `belongs_to :event`, uniqueness validation on `connect_id` scoped to `event_id`
  - Use `normalizes :connect_id, with: ->(v) { v.strip.upcase }` following ConnectedAccount's pattern
  - Add `normalizes :uid, with: ->(v) { v.strip.upcase }` to ConnectedAccount model to ensure case-insensitive matching
  - Data migration to upcase existing passport `uid` values: `ConnectedAccount.where(provider: "passport").find_each { |ca| ca.update(:uid, ca.uid.strip.upcase) }` (use `update` not `update_column` so the normalizer is exercised)
  - **Side effect:** `ConnectController#show` compares `params[:id]` against `passports.pluck(:uid)` using Ruby `include?` — this plain string comparison bypasses ActiveRecord normalization. Must upcase `@connect_id` at assignment in that controller (`@connect_id = params[:id]&.upcase`)

  **Patterns to follow:**
  - `app/models/event_participation.rb` — schema annotation, association/validation/scope section organization
  - `app/models/connected_account.rb` — existing `normalizes :username` pattern

  **Test scenarios:**
  - Happy path: create a verified attendance with valid connect_id, event, and scanned_at
  - Happy path: connect_id is normalized to uppercase on save
  - Happy path: ConnectedAccount.uid is normalized to uppercase on save
  - Edge case: duplicate connect_id + event_id is rejected by validation
  - Edge case: connect_id with leading/trailing whitespace is stripped
  - Error path: missing connect_id raises validation error
  - Error path: missing event raises validation error
  - Error path: missing scanned_at raises validation error

  **Verification:**
  - `VerifiedEventParticipation.create!(connect_id: "abc123", event: event, scanned_at: Time.current)` succeeds and stores connect_id as "ABC123"
  - Duplicate raises `ActiveRecord::RecordNotUnique` or validation error
  - Existing ConnectedAccount passport uids are uppercased after migration

- [ ] **Unit 2: Avo resource and import action**

  **Goal:** Create an Avo resource for browsing verified attendances and an action on the Event resource for CSV import.

  **Requirements:** R4, R5, R10

  **Dependencies:** Unit 1

  **Files:**
  - Create: `app/avo/resources/verified_event_participation.rb`
  - Create: `app/avo/actions/import_verified_event_participation.rb`
  - Modify: `app/avo/resources/event.rb` (register the action)
  - Create: `test/models/verified_event_participation/csv_import_test.rb`

  **Approach:**
  - Avo resource: display connect_id, event (belongs_to), scanned_at. Searchable by connect_id.
  - Avo action on Event resource: `field :file, as: :file` for CSV upload. No event selector needed — the event is the selected record from the resource. Validate exactly one event is selected; return error if multiple.
  - **Avo file upload authorization:** The Avo `FileField` edit component guards the file input behind `can_upload_file?` which delegates to the resource policy's `upload_file?` method. Ensure the Event policy (or Avo's default permissive policy) allows file uploads, or the file input will silently render as `--`. Check this early.
  - CSV parsing: use Ruby's `CSV` stdlib. Parse all rows, group by connect_id (keep earliest scanned_at per connect_id), then upsert. Track created/skipped/errored counts.
  - Row-by-row processing: skip rows with missing connect_id or unparseable timestamp, increment error counter.
  - Use `find_or_create_by` with `connect_id` + `event_id` to handle idempotent re-imports. If record exists, count as duplicate/skipped.
  - Extract the CSV import logic into a method on the model (e.g., `VerifiedEventParticipation.import_from_csv(event:, csv_content:)`) so it's testable without Avo.

  **Patterns to follow:**
  - `app/avo/actions/assign_canonical_speaker.rb` — action structure, field definition, handle method, succeed message
  - `app/avo/resources/event_participation.rb` — resource structure with belongs_to fields

  **Test scenarios:**
  - Happy path: importing a CSV with 5 unique connect_ids creates 5 records for the given event
  - Happy path: import report returns correct created count
  - Happy path: connect_ids are stored uppercased regardless of CSV casing
  - Edge case: CSV with duplicate connect_ids uses earliest timestamp, creates one record
  - Edge case: re-importing same CSV creates 0 new records, reports all as duplicates
  - Edge case: importing overlapping CSVs (some new, some existing) reports correct created + skipped counts
  - Error path: row with blank connect_id is skipped and counted as error
  - Error path: row with unparseable created_at is skipped and counted as error
  - Error path: empty CSV file returns zero counts
  - Integration: import correctly associates all records with the specified event

  **Verification:**
  - Admin can navigate to an Event in Avo, run "Import Verified Event Participation", upload the sample CSV, and see a success message with counts
  - `VerifiedEventParticipation.where(event: event).count` matches expected unique connect_ids from CSV

- [ ] **Unit 3: User model methods for verified attendance**

  **Goal:** Add methods on User to query verified attended events, both standalone and unified with participated_events.

  **Requirements:** R3, R6, R9

  **Dependencies:** Unit 1

  **Files:**
  - Modify: `app/models/user.rb`
  - Create: `test/models/user/verified_event_participation_test.rb`

  **Approach:**
  - Add `User#verified_attended_events` — returns `Event.where(id: VerifiedEventParticipation.where(connect_id: passports.select(:uid)).select(:event_id))`. Uses subqueries to stay as a chainable relation.
  - Add `User#all_attended_events` — plucks IDs from both sources, deduplicates, returns `Event.where(id: (participated_events.pluck(:id) + verified_attended_events.pluck(:id)).uniq)`. Array-based approach is simpler and avoids `.or()` structural compatibility issues with Rails/SQLite. Adequate at this data scale.
  - Add `User#verified_event_ids` — returns a Set of event IDs for verified attendance. Used by the profile view for badge rendering.

  **Patterns to follow:**
  - Existing User associations like `participated_events`, `speaker_events`, `visitor_events`

  **Test scenarios:**
  - Happy path: user with claimed passport and verified attendance returns the correct events from `verified_attended_events`
  - Happy path: user with both self-reported and verified attendance for same event — `all_attended_events` returns event once
  - Happy path: user with only verified attendance (no self-reported) — `all_attended_events` includes the event
  - Happy path: user with only self-reported attendance — `all_attended_events` includes the event
  - Edge case: user with multiple passports — verified attendance from all passports is included
  - Edge case: user with no passports — `verified_attended_events` returns empty relation
  - Edge case: user with passports but no verified attendance — `verified_attended_events` returns empty relation
  - Integration: `verified_event_ids` returns a Set containing the correct event IDs

  **Verification:**
  - `user.verified_attended_events` returns events where the user's passport connect_ids have verified attendance
  - `user.all_attended_events` returns the union of both sources without duplicates
  - Both methods return chainable relations (support `.where`, `.pluck`, `.exists?`)

- [ ] **Unit 4: Stamp integration**

  **Goal:** Make verified attendance count toward passport stamps the same way self-reported attendance does.

  **Requirements:** R9

  **Dependencies:** Unit 3

  **Files:**
  - Modify: `app/models/stamp.rb`
  - Modify: `test/models/stamp_test.rb` (or create if doesn't exist)

  **Approach:**
  - In `Stamp.for_user`, replace `user.participated_events` with `user.all_attended_events`:
    - Line ~91: `user_events = user.all_attended_events` — this local var already cascades to line ~94
    - The three helper methods (`user_attended_triathlon_2025?`, `user_attended_conference?`, `user_attended_online_event?`) each independently call `user.participated_events`. Change them to accept the `user_events` relation as a parameter instead of re-querying, to avoid 8 pluck queries per stamp computation. Pass `user_events` from `for_user` into each helper.
  - Do NOT change `user_spoke_at_conference?` or `user_spoke_at_meetup?` — those use `user.speaker_events`, which is a different concept (speaking, not attending)

  **Patterns to follow:**
  - Existing `Stamp.for_user` structure

  **Test scenarios:**
  - Happy path: user with verified attendance at an event in Colombia earns the Colombia country stamp
  - Happy path: user with verified attendance at an event with an event-specific stamp earns that stamp
  - Happy path: user with verified attendance at all three triathlon events earns the triathlon stamp
  - Happy path: user with verified attendance at a conference earns the "attend one event" stamp
  - Edge case: user with same event in both self-reported and verified — stamp is earned once, no duplication
  - Edge case: user with no passport (no verified attendance) — stamps work exactly as before via participated_events

  **Verification:**
  - `Stamp.for_user(user_with_verified_attendance)` returns stamps matching the verified events' countries and event stamps

- [ ] **Unit 5: Profile events page — unified list with verified badge**

  **Goal:** Merge self-reported and verified attendance into one list on the profile events page, showing a "Verified" badge on events with verified attendance.

  **Requirements:** R6, R7

  **Dependencies:** Unit 3

  **Files:**
  - Modify: `app/controllers/profiles/events_controller.rb`
  - Modify: `app/controllers/profiles_controller.rb` (also renders `_events` partial in `show`)
  - Modify: `app/views/profiles/_events.html.erb`
  - Modify: `app/views/profiles/events/index.html.erb` (passes locals to `_events` partial)
  - Modify: `app/views/profiles/show.html.erb` (passes locals to `_events` partial)
  - Modify: `app/views/events/_card.html.erb` (update locals declaration)
  - Create: `test/controllers/profiles/events_controller_test.rb` (or modify existing)

  **Approach:**
  - **Both controllers render `_events` partial:** `Profiles::EventsController#index` and `ProfilesController#show` both render the `_events` partial with `events`, `participations`, and `user` locals. Both must be updated to also pass `verified_event_ids`.
  - Controller logic: keep existing `participated_events` query. Add a second query for verified-only events (events where user has verified attendance but no EventParticipation). Merge both collections into `@events`. Build `@verified_event_ids` Set for the view. Consider extracting the merge logic into a helper method so both controllers share it.
  - Pass `verified_event_ids` to the `_events` partial via locals.
  - The `_events` partial splits events into future/past (not year grouping). Pass `verified: verified_event_ids.include?(event.id)` to the card partial for each event.
  - **Card partial locals update:** Update `_card.html.erb` line 1 from `<%# locals: (event:, participation: nil) %>` to `<%# locals: (event:, participation: nil, verified: false) %>`. The default `false` ensures all existing callers (home page, browse page, featured events) work without modification.
  - In `_card.html.erb`: add a "Verified" badge (e.g., `ui_badge("Verified", ...)` with a distinct color like green) when `verified` is true. Show alongside the existing `attended_as` badge, not replacing it.
  - Update fragment cache keys to include `verified_event_ids` so the cache busts when verified attendance changes.
  - **Intentional non-change:** `ProfileData#load_common_data` sets `@events` for `@events_with_stickers` and `@countries_with_events`. These remain on `participated_events` only. Verified attendance affecting stickers/map/countries is deferred.

  **Patterns to follow:**
  - Existing `@participations` hash pattern in the events controller
  - Existing `ui_badge` usage in `_card.html.erb`

  **Test scenarios:**
  - Happy path: user with self-reported attendance sees events listed as before (no regression)
  - Happy path: user with verified attendance for an event they also self-reported sees the verified badge alongside the attended_as badge
  - Happy path: user with verified-only attendance (no self-report) sees the event in the list with verified badge
  - Happy path: profile show page (not just events tab) also shows verified events with badge
  - Edge case: user with no attendance of either kind sees the empty state message
  - Edge case: user with unclaimed passport — verified attendance exists in DB but user doesn't see it (no ConnectedAccount link)
  - Integration: profile page for a user with mixed self-reported and verified events renders correctly with proper badges

  **Verification:**
  - Profile events page shows events from both sources in a single unified list split into future/past
  - Events with verified attendance display a "Verified" badge
  - Events with only self-reported attendance display only the attended_as badge (no regression)
  - Both profile show page and dedicated events page display verified badges consistently

- [ ] **Unit 6: Event page — verified attendee count**

  **Goal:** Show the number of verified attendees on event pages.

  **Requirements:** R8

  **Dependencies:** Unit 1

  **Files:**
  - Modify: `app/views/events/show.html.erb`
  - Modify: `app/controllers/events_controller.rb` (compute count in `show` action — EventData concern is NOT included by this controller)
  - Create: `test/system/events/verified_event_participation_test.rb` (or add to existing event system test)

  **Approach:**
  - In `EventsController#show`, compute `@verified_attendees_count` by joining VerifiedEventParticipation (for this event) through ConnectedAccount to get the count of distinct users who have claimed their passports.
  - Query: `VerifiedEventParticipation.where(event: @event).joins("INNER JOIN connected_accounts ON connected_accounts.uid = verified_event_participations.connect_id AND connected_accounts.provider = 'passport'").select("DISTINCT connected_accounts.user_id").count`
  - Display as a stat card with count and label "Verified Attendees". The event show page has conditional layout: retreat-type events show "Known Participants" count; non-retreats show Talks/Speakers/Sponsors. Place the verified attendee count in both branches when > 0, or decide during implementation which event types warrant it.
  - Only show the count when > 0.

  **Patterns to follow:**
  - Existing participant count display at `app/views/events/show.html.erb:24-25` (retreat branch)
  - Existing stat card grid layout on the event show page

  **Test scenarios:**
  - Happy path: event with 3 verified attendees (all passports claimed) shows "3 Verified Attendees"
  - Edge case: event with verified attendance records but no claimed passports shows nothing (count = 0)
  - Edge case: event with no verified attendance records shows nothing
  - Edge case: same user with multiple passports scanned — counts as 1 verified attendee
  - Integration: importing a CSV for an event and visiting the event page shows the correct count

  **Verification:**
  - Event show page displays "X Verified Attendees" next to "Known Participants" when verified attendance data exists

## System-Wide Impact

- **Interaction graph:** The import creates VerifiedEventParticipation records. These are read by: (1) User model methods for profile and stamps, (2) Event show page for count display. No callbacks, observers, or middleware involved.
- **Error propagation:** Import errors are contained per-row and reported in the Avo action result. No downstream failures — verified attendance is additive, never destructive.
- **State lifecycle risks:** None significant. VerifiedEventParticipation records are immutable after creation. The only mutable path is admin deletion via Avo.
- **Cache invalidation:** Profile events partial uses fragment caching keyed on `[user, events, Current.user]`. Adding `verified_event_ids` to the cache key ensures bust on verified attendance changes. Inner per-card cache keyed on `[event, participations[event.id]]` — for verified-only events, `participations[event.id]` will be nil, which is a valid cache key.
- **Unchanged invariants:** EventParticipation model, self-reported attendance flow, and the following `participated_events` call sites intentionally remain unchanged:
  - `ProfileData#load_common_data` — `@events_with_stickers`, `@countries_with_events`
  - `ProfileData#set_mutual_events` — mutual events between two users
  - `Profiles::WrappedController` and `User::WrappedScreenshotGenerator` — year-in-review
  - `Profiles::MapController`, `Profiles::StickersController` — map pins and stickers
  - `BrowseController` — browse/discover pages
  - `Events::AttendancesController` — talk attendance tracking
  - `Api::V1::Embed::StickersController` — embed API
  These can be expanded to include verified attendance in future iterations if needed.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Case mismatch between stored ConnectedAccount.uid and CSV connect_id | Addressed in Unit 1: add `normalizes :uid` to ConnectedAccount + data migration to upcase existing passport uids. |
| Avo file upload field behavior unknown (no existing example in codebase) | Avo supports `field :file, as: :file` in actions. Test early in Unit 2. |
| Fragment cache not busting after verified attendance import | Include verified_event_ids in cache key (Unit 5 approach section). |
| Card partial has multiple callers that don't pass `verified:` | Default `verified: false` in locals declaration ensures backward compatibility. |
| Card collection caching may serve stale non-verified version | Collection renders with `cached: true` use `event.cache_key_with_version` which doesn't include verified state. The `_events` partial uses per-card fragment caching with `[event, participations[event.id]]` which will naturally differ (verified-only events have nil participation). Monitor for staleness; can add `verified` to inner cache key if needed. |
| Avo file upload authorization gate | `FileField` guards behind `upload_file?` policy method. If Event policy doesn't permit it, file input renders as `--`. Check early in Unit 2. |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-07-verified-attendance-requirements.md](docs/brainstorms/2026-04-07-verified-attendance-requirements.md)
- Related code: `app/models/event_participation.rb`, `app/models/connected_account.rb`, `app/models/stamp.rb`, `app/models/user.rb`
- Sample CSV: `rucoco-26_attendance_20260407_113731.csv`
