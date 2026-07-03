json.talks @talks do |talk|
  json.title talk.title
  json.video_id talk.video_id
  json.video_provider talk.video_provider
  json.date talk.date
  json.parent_talk_slug talk.parent_talk&.slug
  json.child_talks_slugs talk.child_talks.pluck(:slug)
  json.language talk.language
  json.url talk_url(talk)
  json.video_id talk.video_id
  json.video_provider talk.video_provider
  json.slug talk.slug
  json.static_id talk.static_id

  json.event do
    json.slug talk.event&.slug
    json.name talk.event&.name
    json.url talk.event ? event_url(talk.event) : nil
  end

  json.speakers talk.speakers do |speaker|
    json.slug speaker.slug
    json.name speaker.name
    json.url profile_url(speaker)
  end
end

json.pagination do
  json.current_page @pagy.page
  json.total_pages @pagy.pages
  json.total_count @pagy.count
  json.next_page @pagy.next
  json.prev_page @pagy.prev
end
