---
title: "RubyEvents.org March 2026 Newsletter"
slug: march-2026-newsletter
date: 2026-04-01
author: chaelcodes
published: true
excerpt: |-
  In March, RubyEvents had TODO contributors and TODO PRs merged! This month, we had Ruby Community Conference Winter Edition and RBQConf. April will be busy with 5 different events - Tropical on Rails, wroclove.rb, RubyKaigi, Haggis Ruby, and Blue Ridge Ruby!
tags:
  - newsletter
  - march
  - 2026
featured_image:
---

In March, RubyEvents had TODO contributors and TODO PRs merged! This month, we had Ruby Community Conference Winter Edition and RBQConf. April will be busy with 5 different events - Tropical on Rails, wroclove.rb, RubyKaigi, Haggis Ruby, and Blue Ridge Ruby!

## This month's events

- [Ruby Community Conference Winter Edition](https://www.rubyevents.org/events/ruby-community-conference-winter-edition-2026) was in Kraków, Poland on March 13th.
- [RBQConf](https://www.rubyevents.org/events/rbqconf-2026) was in Austin, TX from March 26-27.

## Next month's events

- [Tropical on Rails](https://rubyevents.org/events/tropical-on-rails-2026) will be in São Paulo, Brazil on April 9-10. [Ticket](https://www.sympla.com.br/evento/tropical-on-rails-2026-the-brazilian-rails-conference/3181423) sales end TODAY! You can buy workshop tickets until April 4. Tickets are between R$ 649-1.048. _Meet RubyEvents Team Members - Marco Roth and Rachael Wright-Munn!_
- [wroclove.rb](https://rubyevents.org/events/wroclove-rb-2026) will be in Wrocław, Poland from April 17-19. [Tickets](https://wrocloverb2026.konfeo.com/en/groups) are 123.00 EUR and there are very few left!
- [RubyKaigi](https://rubyevents.org/events/rubykaigi-2026) will be in Hakodate, Hokkaido, Japan from April 22-24. [Tickets](https://ti.to/rubykaigi/2026) are ¥30,000-¥40,000 (¥5,000 for students).
- [Haggis Ruby](https://rubyevents.org/events/haggis-ruby-2026) will be in Glasgow, Scotland, UK from April 23-24.[Tickets](https://ti.to/haggis-ruby/haggis-ruby-2026) are £230!
- [Blue Ridge Ruby](https://rubyevents.org/events/blue-ridge-ruby-2026) will be in Asheville, NC, United States from April 30-May 1. [Tickets](https://ti.to/blue-ridge-ruby/blue-ridge-ruby-2026) are $249 for individual and $499 for corporate. There will be optional events the Saturday after the conference including river tubing and a Hack Day. _Meet RubyEvents team member, Rachael Wright-Munn, who'll be talking about open-source contributing, and join her on Hack Day to work on RubyEvents!_

## Open CFPs

- [Deccan Queen on Rails](https://www.rubyevents.org/events/deccan-queen-on-rails-2026/cfp) will be in Pune, Maharashtra, India from October 8-9. The [CFP](https://cfp.deccanqueenonrails.com/) closes May 31.
- [tiny ruby #{conf}](https://www.rubyevents.org/events/tiny-ruby-conf-2026/cfp) will be in Helsinki, Finland on October 1. The [CFP](https://cfp.helsinkiruby.fi) closes June 14.

## Uploaded videos

- [RubyConf India 2017](https://www.rubyevents.org/events/rubyconf-india-2017/talks) added 14 talks!
- [RubyConf India 2018](https://www.rubyevents.org/events/rubyconf-india-2018/talks) added 15 talks!
- [RubyConf India 2022](https://www.rubyevents.org/events/rubyconf-india-2022/talks) added 10 talks!
- [Vienna.rb Meetup](https://www.rubyevents.org/talks/vienna-rb-march-2026) added the March meetup with 3 talks!

## Contributions

We had 12 contributors this month and 55 merged PRs!

TODO - contributions

```
   gh pr list --repo RubyEvents/RubyEvents \
     --limit 100 \
     --state merged \
     --search "merged:>=2026-03-01" \
     --json author,number,title,url \
     --jq 'group_by(.author.login)[] | "### \(.[0].author.name) (@\(.[0].author.login))\n" + (map("- \(.title) [(#\(.number))](\(.url))") | join("\n"))'
```

### Platform Updates

Meetups have seen some major improvements this month!
Meetups are now listed on the events page under a separate [Meetups](https://www.rubyevents.org/events/meetups) link.

- https://github.com/rubyevents/rubyevents/pull/1511

When viewing a location (city/region/country), you can now see a tab that lists all meetups for that location.

### Rachael Wright-Munn (@ChaelCodes)

- Tropical on Rails updates [(#1524)](https://github.com/rubyevents/rubyevents/pull/1524)
- RBQConf 2026 Updates [(#1521)](https://github.com/rubyevents/rubyevents/pull/1521)
- Update to Schedule and Talks for RuCoCo 2026 [(#1520)](https://github.com/rubyevents/rubyevents/pull/1520)
- Isolate Generator specs [(#1497)](https://github.com/rubyevents/rubyevents/pull/1497)
- Add RubyKaigi 2026 Speakers [(#1496)](https://github.com/rubyevents/rubyevents/pull/1496)
- Fix Event Attendance Button [(#1485)](https://github.com/rubyevents/rubyevents/pull/1485)
- Tropical on Rails Workshops and Talk Generator Improvements [(#1481)](https://github.com/rubyevents/rubyevents/pull/1481)
- February 2026 Newsletter! [(#1471)](https://github.com/rubyevents/rubyevents/pull/1471)
- Favorite User Notes [(#1469)](https://github.com/rubyevents/rubyevents/pull/1469)
- ScheduleGenerator [(#1458)](https://github.com/rubyevents/rubyevents/pull/1458)

### Vishwajeetsingh Desurkar (@Selectus2)

- Add deccan queen on rails details for 2026 edition [(#1486)](https://github.com/rubyevents/rubyevents/pull/1486)

### null (@app/copilot-swe-agent)

- Change February 2026 Newsletter published date to March 1, 2026 [(#1477)](https://github.com/rubyevents/rubyevents/pull/1477)
- Add Typesense and FastRuby.io sponsors to Blue Ridge Ruby 2026 [(#1475)](https://github.com/rubyevents/rubyevents/pull/1475)
- New Talks for Blastoff Rails 2026 [(#1473)](https://github.com/rubyevents/rubyevents/pull/1473)

### Ender Ahmet Yurt (@enderahmetyurt)

- Revert showing up all button [(#1514)](https://github.com/rubyevents/rubyevents/pull/1514)
- Fix past scope to include events with missing dates [(#1479)](https://github.com/rubyevents/rubyevents/pull/1479)

### Francois DUMAS LATTAQUE (@francoisedumas)

- Nantes RB update [(#1527)](https://github.com/rubyevents/rubyevents/pull/1527)
- Add Nantes Rb meetup [(#1483)](https://github.com/rubyevents/rubyevents/pull/1483)

### Hans Schnedlitz (@hschne)

- Videos for Vienna.rb March 2026 [(#1517)](https://github.com/rubyevents/rubyevents/pull/1517)
- Change name for Eileen Alayce [(#1508)](https://github.com/rubyevents/rubyevents/pull/1508)

### Marco Roth (@marcoroth)

- Add EuRuKo 2026 assets [(#1482)](https://github.com/rubyevents/rubyevents/pull/1482)

### Matt Mayer (@matthewmayer)

- Date fixes for Thailand data [(#1522)](https://github.com/rubyevents/rubyevents/pull/1522)
- Add videos for RubyConf India 2017 [(#1515)](https://github.com/rubyevents/rubyevents/pull/1515)
- Bugfixes for contributions page [(#1513)](https://github.com/rubyevents/rubyevents/pull/1513)
- fix typo in attended one conference badge [(#1506)](https://github.com/rubyevents/rubyevents/pull/1506)
- add RubyAndRails 2010 (former RubyEnRails) [(#1505)](https://github.com/rubyevents/rubyevents/pull/1505)
- fix typo of 'calendar' [(#1504)](https://github.com/rubyevents/rubyevents/pull/1504)
- Add videos for RubyConf India 2018 and 2022 [(#1500)](https://github.com/rubyevents/rubyevents/pull/1500)
- Add docs for adding meetups [(#1495)](https://github.com/rubyevents/rubyevents/pull/1495)
- Sort by series name case insensitive on /events/archive [(#1494)](https://github.com/rubyevents/rubyevents/pull/1494)
- Add Meetups tab to countries, states and cities [(#1492)](https://github.com/rubyevents/rubyevents/pull/1492)
- Add bangkok.rb's Ruby Tuesday meetup with historical data [(#1487)](https://github.com/rubyevents/rubyevents/pull/1487)
- combine windy city rails series [(#1463)](https://github.com/rubyevents/rubyevents/pull/1463)
- sort speakers.yml [(#1462)](https://github.com/rubyevents/rubyevents/pull/1462)
- Show playlists for events with no videos page [(#1451)](https://github.com/rubyevents/rubyevents/pull/1451)

### Sudeep Tarlekar (@sudeeptarlekar)

- Sort conferences on CFPs at the top [(#1525)](https://github.com/rubyevents/rubyevents/pull/1525)
- Fix polymorphic path in maps controller [(#1509)](https://github.com/rubyevents/rubyevents/pull/1509)

### Vinícius Alonso (@viniciusalonso)

- Add upcoming events link in meetups page [(#1519)](https://github.com/rubyevents/rubyevents/pull/1519)
- Create an initial version of meetups page [(#1511)](https://github.com/rubyevents/rubyevents/pull/1511)
- Remove stamp code [(#1510)](https://github.com/rubyevents/rubyevents/pull/1510)
- Order sponsors by tier level [(#1499)](https://github.com/rubyevents/rubyevents/pull/1499)
- Add filter kind in events archived [(#1478)](https://github.com/rubyevents/rubyevents/pull/1478)

Thank you to everyone for your contributions! ❤️

> Looking to join this list in April? Check out our [contributions page](https://www.rubyevents.org/contributions) or the [CONTRIBUTING.md](https://github.com/rubyevents/rubyevents/blob/main/CONTRIBUTING.md) in GitHub.
