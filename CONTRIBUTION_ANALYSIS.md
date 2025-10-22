# RubyEvents.org Contribution Analysis

**Generated:** 2025-10-22
**Purpose:** Guide contribution strategy based on current issues, PRs, and recent activity

---

## 📊 SUMMARY OF FINDINGS

Based on analysis of:
- 100+ open issues in the repository
- Recent 30 days of commit history
- Open pull requests
- The contributions page structure

### Key Insights:
1. ✅ **Data contributions are VERY active** - 25+ data PRs merged in last 30 days
2. ✅ **No major conflicts** - Most contribution types are safe to work on
3. ⚠️ **One assigned issue** - Issue #1091 (geocoder gem) is assigned to @enderahmetyurt
4. ✅ **Active maintainers** - Fast PR review/merge times (1-3 days typical)

---

## 🔍 STATUS OF EACH CONTRIBUTION TYPE

### 1. Speakers without GitHub handles
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:**
- PR #1089 (OPEN): Correcting speaker name for Fable Phippen
- Multiple speaker data updates in recent commits

**Recommendation:** **START HERE!**
- No conflicts or active issues
- Simple, well-defined task
- High acceptance rate for speaker data PRs
- Good first contribution

---

### 2. Events without locations
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:** None specifically related
**Recommendation:** Safe choice for 2nd-3rd contribution
- No conflicts
- Straightforward data addition
- Recent commit: "Update SF Ruby 2025 involvements" shows location data being updated

---

### 3. Events without conference dates
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:**
- Recent commit: "Update RubyConf Austria 2026 dates"
- Multiple date-related updates

**Recommendation:** Good choice
- Active area but no conflicts
- Clear validation criteria
- Recent examples show format

---

### 4. Talks without slides
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:**
- Recent commit: "Add Marco Roth's slides_url"

**Recommendation:** Excellent choice
- Requires research but not coding
- Recent example shows this is actively accepted
- No conflicts

---

### 5. Review Talk Dates (talks_dates_out_of_bounds)
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:** None specific
**Recommendation:** Good for 3rd+ contribution
- More complex than simple data entry
- Requires understanding date ranges
- No conflicts

---

### 6. Overdue scheduled talks
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:** None specific
**Recommendation:** Good intermediate task
- Requires research to determine status
- No conflicts

---

### 7. Not published talks
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:**
- Recent commits: "Add first EuRuKo 2025 talks", "Add `published_at` dates for EuRuKo 2025 talks"

**Recommendation:** Active area, safe to work on
- Requires finding published videos
- Recent activity shows this is welcome
- No conflicts

---

### 8. Talks without speakers
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:**
- PR #1088: "Add second presenter Nathaniel Bibler" (MERGED)

**Recommendation:** Good choice
- May require video watching
- Recent PRs show this is actively maintained
- No conflicts

---

### 9. Missing Video Cues
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:** None specific
**Recommendation:** Advanced task
- Requires video analysis
- Time-consuming
- No conflicts but more complex

---

### 10. Events without schedule
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:**
- Multiple schedule additions: "Add Bath Ruby 2016 schedule", "Add Deccan RubyConf 2016 schedule/videos", "Add XO Ruby San Diego 2025 talks and schedule"

**Recommendation:** **VERY ACTIVE AREA**
- Many recent schedule contributions
- Good opportunity if you have schedule data
- No conflicts

---

### 11. Add missing events
**Status:** ⚠️ ONE SPECIFIC EVENT CLAIMED
**Recent Activity:**
- Issue #1079 (OPEN): "Add Rails Hackathon" - marked with "content" label, 1 comment, opened Oct 18
- PR #1090 (MERGED): "Add talks and videos for Scottish Ruby 2014"
- PR #1086 (MERGED): "Add Brighton Ruby 2026 event and assets"
- Multiple event additions in recent commits

**Recommendation:** **VERY ACTIVE, MOSTLY SAFE**
- AVOID: Rails Hackathon (issue #1079 exists)
- SAFE: Any other missing events from the contributions page
- This is the most active contribution type
- Requires full workflow knowledge (scripts, YAML structure)

---

### 12. Events without videos
**Status:** ✅ SAFE TO WORK ON
**Recent Activity:** None specific
**Recommendation:** Research-heavy task
- Requires identifying which events should have videos
- No conflicts

---

## 🎯 RECOMMENDED CONTRIBUTION STRATEGY

### Phase 1: Quick Wins (Start This Week)

**First PR:**
1. **Speakers without GitHub handles** (2-5 speakers)
   - Zero conflicts
   - Fast review/merge
   - Builds confidence

**Second PR:**
2. **Talks without slides** (3-5 talks)
   - Recent PR shows active acceptance
   - Good research practice
   - Or **Events without locations** (2-3 events)

### Phase 2: Intermediate Contributions (Week 2-3)

3. **Events without dates** (2-3 events)
4. **Not published talks** (2-3 talks) - Very active area!
5. **Events without schedule** (1-2 schedules) - High value, actively wanted

### Phase 3: Advanced (Week 4+)

6. **Add missing events** - Full workflow
   - AVOID: Rails Hackathon (#1079)
   - PICK: Any other event from rubyconferences.org list

---

## ⚠️ CURRENT CONFLICTS TO AVOID

1. **Issue #1079** - Rails Hackathon addition (someone may be working on it)
2. **Issue #1091** - Geocoder gem adoption (assigned to @enderahmetyurt)
3. **Issue #1093** - Event organizers feature (open discussion)
4. **PR #1089** - Fable Phippen name correction (wait for merge if you find related issues)

---

## ✅ BEST FIRST CONTRIBUTION TODAY

**Recommended Action:**
1. Visit https://www.rubyevents.org/contributions (or run locally: `bin/setup && bin/dev`)
2. Click "Speakers without GitHub handles" tab
3. Pick 3-5 speakers with most talks
4. Research their GitHub profiles (search Twitter, LinkedIn, conference sites)
5. Add GitHub handles to `data/speakers.yml`
6. Create PR with title: "Add GitHub handles for [Speaker1], [Speaker2], [Speaker3]"

**Why this is perfect:**
- ✅ No conflicts with existing work
- ✅ Recent similar PRs merged successfully
- ✅ Clear success criteria
- ✅ Low technical complexity
- ✅ High impact (improves speaker profiles)
- ✅ Fast review cycle (1-2 days typical)

---

## 📈 PROJECT HEALTH INDICATORS

- **Open Issues:** ~100 (mix of features and data)
- **Open PRs:** ~10
- **Merge Rate:** Very fast (1-3 days for data PRs)
- **Contributor Friendly:** Yes - many first-time contributors successful
- **Data Contribution Activity:** VERY HIGH (25+ PRs in 30 days)
- **Maintainer Response:** Active daily

---

## 🤝 CONTRIBUTING TIPS

1. **Small PRs win** - 2-5 items per PR gets faster reviews than 50 items
2. **Data format matters** - Look at recent merged PRs for format examples
3. **Run linter** - `bin/lint` before committing (saves review cycles)
4. **Link sources** - In PR description, mention where you found the information
5. **Watch for CI** - Fix any test failures quickly
6. **Be patient with CI** - Sometimes tests are flaky, maintainers will help

---

## 📚 USEFUL RESOURCES

- **Main Repo:** https://github.com/rubyevents/rubyevents
- **Contributions Page:** https://www.rubyevents.org/contributions
- **Contributing Guide:** docs/contributing.md
- **Recent Data PRs:** Filter by label "content"
- **Good First Issues:** Label "good first issue" (#1065 currently open)

---

## ❓ NEXT STEPS

Would you like me to:
1. **Help you make your first PR** - I can find speakers without GitHub handles and create the PR
2. **Show the current data format** - Read `data/speakers.yml` to understand structure
3. **Run the app locally** - Set up and show you the contributions page live
4. **Research a specific contribution type** - Deep dive into any area

Let me know what you'd like to tackle first!
