---
date: 2026-04-07
topic: verified-attendance
---

# Verified Attendance

## Problem Frame

RubyEvents.org tracks self-reported event attendance via EventParticipation, but there's no way to distinguish "I clicked a button" from "I was physically there." Event organizers using the Ruby Passport scanning app already collect proof of attendance (QR code scans), but this data has no path into RubyEvents.org. Verified attendance builds trust in attendance data, rewards attendees with a visible distinction on their profiles, and gives event organizers accurate headcounts.

## User Flow

```
                    ┌──────────────────────┐
                    │  Organizer exports    │
                    │  CSV from scan app    │
                    └──────────┬───────────┘
                               │
                               v
                    ┌──────────────────────┐
                    │  Admin opens Avo      │
                    │  action, selects      │
                    │  Event, uploads CSV   │
                    └──────────┬───────────┘
                               │
                               v
                    ┌──────────────────────┐
                    │  Import creates       │
                    │  VerifiedEventParticipation   │
                    │  records (deduped     │
                    │  by connect_id+event) │
                    └──────────┬───────────┘
                               │
              ┌────────────────┼────────────────┐
              v                v                v
   ┌─────────────────┐ ┌────────────┐ ┌──────────────────┐
   │ Profile events   │ │ Event page │ │ Stamp system     │
   │ page: unified    │ │ shows      │ │ counts verified  │
   │ list merging     │ │ verified   │ │ attendance for   │
   │ self-reported +  │ │ attendee   │ │ country/event    │
   │ verified, badge  │ │ count      │ │ stamps           │
   │ on verified      │ │            │ │                  │
   └─────────────────┘ └────────────┘ └──────────────────┘
```

## Requirements

**Data Model**

- R1. A `VerifiedEventParticipation` model stores verified attendance records, keyed by `connect_id` (6-character passport code) and `event_id`, with the scan timestamp from the CSV.
- R2. One verified attendance per `connect_id` per event (enforced by unique composite index). Duplicate scans within a CSV are deduplicated using the earliest timestamp. Re-importing the same CSV or overlapping CSVs skips already-existing records (counted as "duplicates" in the import report).
- R3. Records are stored by `connect_id`, not `user_id`. The link to a user is resolved at read time through `ConnectedAccount` (provider: "passport", uid: connect_id). A user may have multiple passport ConnectedAccounts, so queries must handle a set of connect_ids. Unclaimed passport codes are stored and automatically appear when the user later claims their passport.
- R10. The `connect_id` is uppercased on import to ensure case-insensitive matching with `ConnectedAccount.uid`.

**Admin Import**

- R4. An Avo action allows an admin to select an Event, upload a CSV file, and import verified attendance records for that event. The CSV's `event` column is informational only — the selected Event determines the target.
- R5. The import reports how many records were created, how many were duplicates (skipped), and how many had errors. Import is row-by-row with partial success — a bad row (missing connect_id, unparseable timestamp) is skipped and counted as an error, not a transaction rollback.

**Profile Display**

- R6. The profile events page shows a single unified list of all events the user attended, merging self-reported (EventParticipation) and verified (VerifiedEventParticipation) sources. An event appears once even if the user has both self-reported and verified attendance.
- R7. Events with verified attendance display a "Verified" badge. Three states per event: self-reported only (no badge), self-reported + verified (verified badge), verified only (appears automatically with verified badge).

**Event Page Display**

- R8. Event pages show verified attendee information (count or list of verified attendees who have claimed their passport).

**Stamps Integration**

- R9. Verified attendance counts toward passport stamps (country stamps, event stamps, triathlon, etc.) the same way self-reported EventParticipation does.

## Success Criteria

- An admin can upload a CSV from the scanning app and see verified attendance records created for the correct event
- A user who claimed their passport sees their verified attendances on their profile without any manual action
- A user who claims their passport after import sees their verified attendances appear retroactively
- Verified attendance feeds into the stamp system (e.g., attending RuCoCo in Colombia earns the Colombia stamp)

## Scope Boundaries

- No real-time sync with the scanning app — CSV export/import only
- No API endpoint for the scanning app to push data directly (can be added later)
- No user-facing UI for claiming or disputing verified attendance
- No changes to the EventParticipation model — verified attendance is a separate concept
- No deduplication between self-reported and verified attendance (a user can have both)

## Key Decisions

- **Store by connect_id, not user_id**: Decouples import from user registration. Resolved at read time via ConnectedAccount join. Simpler import, handles unclaimed passports gracefully.
- **Admin selects event during import**: Avoids needing a mapping table between external event slugs and internal Event records. The CSV's event field is ignored for matching purposes.
- **Unified list on profile with verified badge**: Rather than a separate section, merge all attended events into one list. Events with verified attendance get a badge. This avoids confusing duplication and makes the verified badge a reward, not a separate page section.
- **Deduplicate on import**: One record per connect_id per event. Re-scans are noise, not signal. Re-imports are idempotent.
- **Uppercase connect_id on import**: Prevents silent join failures if the scanning app or claim flow uses different casing.
- **Row-by-row error handling**: A single malformed row shouldn't block importing the other 80 valid attendees.

## Dependencies / Assumptions

- The scanning app consistently uses the same 6-character hex codes that match `ConnectedAccount.uid`
- Event organizers will provide CSVs in the format: `connect_id,event,scan_type,created_at`
- The Avo admin panel is the appropriate place for this import (no need for a standalone admin page)

## Outstanding Questions

### Deferred to Planning

- [Affects R8][Needs research] What exactly should the event page show — a count of verified attendees, a list of user avatars, or both?
- [Affects R6][Technical] How should the unified events query merge EventParticipation and VerifiedEventParticipation into a single deduplicated list while preserving year grouping?
- [Affects R9][Technical] `Stamp.for_user` calls `user.participated_events` in ~6 places. The recommended approach is a unified `User#all_attended_events` method (or similar) that merges participated_events with verified attendance events, so each stamp check doesn't need individual modification. Planner should confirm this approach and determine the query shape (join through ConnectedAccount).
- [Affects R8][Technical] Should the verified attendee count on event pages be cached (counter cache or fragment cache) or computed live? For events with many attendees, a live 3-table join on every page view may be costly.

## Next Steps

-> `/ce:plan` for structured implementation planning
