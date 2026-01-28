---
title: "Introducing Web Components for RubyEvents.org"
slug: introducing-web-components
date: 2026-01-21
author: marcoroth
published: false
excerpt: "Speakers and organizers can now embed parts of RubyEvents.org on their own websites using simple web components. Display talks, speakers, events, and more with just a single HTML tag!"
tags:
  - feature
  - web-components
  - embed
featured_image:
---

We're excited to announce a new way to share Ruby community content: **Web Components for RubyEvents.org**!

Speakers, organizers, and community members can now embed parts of RubyEvents.org directly into their own websites, blogs, or documentation using simple HTML tags. No JavaScript configuration required – just drop in a tag and you're done!

## Getting Started

Add the RubyEvents.org script to your page:

```html
<script type="module" src="https://www.rubyevents.org/embed.js"></script>
```

Then use any of the components below!

---

## Talk Component

Display a single talk with video thumbnail, speakers, and event info.

```html
<rubyevents-talk slug="keynote-rubyllm" show-footer></rubyevents-talk>
```

<div class="my-6 p-4 bg-base-200 rounded-lg">
<rubyevents-talk slug="keynote-rubyllm" show-footer></rubyevents-talk>
</div>

---

## Speaker Component

Display a speaker profile with their talks and events.

```html
<rubyevents-speaker slug="tenderlove" tab="talks"></rubyevents-speaker>
```

<div class="my-6 p-4 bg-base-200 rounded-lg">
<rubyevents-speaker slug="tenderlove" tab="talks"></rubyevents-speaker>
</div>

---

## Topic Component

Display talks for a specific topic.

```html
<rubyevents-topic slug="truffleruby" limit="10"></rubyevents-topic>
```

<div class="my-6 p-4 bg-base-200 rounded-lg">
<rubyevents-topic slug="truffleruby" limit="10"></rubyevents-topic>
</div>

---

## Events Component

Display a list of upcoming or past events.

```html
<rubyevents-events filter="upcoming" show-filter></rubyevents-events>
```

<div class="my-6 p-4 bg-base-200 rounded-lg">
<rubyevents-events filter="upcoming" show-filter></rubyevents-events>
</div>

---

## Event Component

Display a single event with details, stats, and participant avatars.

```html
<rubyevents-event slug="rubyconf-2024" show-participants></rubyevents-event>
```

<div class="my-6 p-4 bg-base-200 rounded-lg">
<rubyevents-event slug="rubyconf-2024" show-participants></rubyevents-event>
</div>

---

## Profile Component

Display a user profile with attending events and watch lists.

```html
<rubyevents-profile slug="chaelcodes"></rubyevents-profile>
```

<div class="my-6 p-4 bg-base-200 rounded-lg">
<rubyevents-profile slug="chaelcodes"></rubyevents-profile>
</div>

---

## Passport Component

Display a user's stamps in a passport/stamp book style layout.

```html
<rubyevents-passport slug="chaelcodes"></rubyevents-passport>
```

<div class="my-6 p-4 bg-base-200 rounded-lg">
<rubyevents-passport slug="chaelcodes"></rubyevents-passport>
</div>

---

## Stickers Component

Display a user's stickers on a MacBook-style laptop lid.

```html
<rubyevents-stickers slug="chaelcodes"></rubyevents-stickers>
```

<div class="my-6 p-4 bg-base-200 rounded-lg">
<rubyevents-stickers slug="chaelcodes"></rubyevents-stickers>
</div>

---

## Use Cases

- **Speakers**: Embed your talk history on your personal website or portfolio
- **Event Organizers**: Showcase upcoming events and past recordings on your conference site
- **Community Blogs**: Feature talks on specific topics in your blog posts
- **Company Pages**: Highlight your team's conference participation

## What's Next?

We're just getting started! We'd love to hear your feedback and ideas for new components or features. Feel free to open an issue on [GitHub](https://github.com/rubyevents/rubyevents) or reach out to us on social media.

Happy embedding! 🎉
