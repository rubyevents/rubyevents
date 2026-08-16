json.talk do
  json.id @talk.id
  json.slug @talk.slug
  json.title @talk.title
  json.original_title @talk.original_title
  json.description @talk.description
  json.summary @talk.summary
  json.date @talk.date
  json.formatted_date @talk.formatted_date
  json.kind @talk.kind
  json.video_provider @talk.video_provider
  json.video_id @talk.video_id
  json.video_url @talk.provider_url
  json.thumbnail_url @talk.thumbnail_xl
  json.duration_in_seconds @talk.duration_in_seconds
  json.slides_url @talk.slides_url

  if @talk.event.present?
    json.event do
      json.slug @talk.event.slug
      json.name @talk.event.name
      json.start_date @talk.event.start_date
      json.end_date @talk.event.end_date
      json.location @talk.event.location

      if @talk.event.avatar_image_path.present?
        json.avatar_url Router.image_path(@talk.event.avatar_image_path, host: "#{request.protocol}#{request.host}:#{request.port}")
      end

      if @talk.event.series.present?
        json.series do
          json.id @talk.event.series.id
          json.name @talk.event.series.name
          json.slug @talk.event.series.slug
        end
      end
    end
  end

  json.speakers @talk.speakers do |user|
    json.id user.id
    json.name user.name
    json.slug user.slug
    json.bio user.bio
    json.avatar_url user.avatar_url
    json.github_handle user.github_handle
  end

  json.topics @talk.approved_topics do |topic|
    json.id topic.id
    json.name topic.name
    json.slug topic.slug
  end

  json.transcript do
    json.raw @talk.raw_transcript
    json.enhanced @talk.enhanced_transcript
  end

  json.related_talks @talk.related_talks do |related|
    json.id related.id
    json.title related.title
    json.slug related.slug
    json.url talk_url(related)
    json.thumbnail_url related.thumbnail_xl
    json.duration_in_seconds related.duration_in_seconds
    json.event_name related.event&.name.to_s
    json.video_provider related.video_provider
    json.video_url related.provider_url
    json.speakers related.speakers do |speaker|
      json.id speaker.id
      json.name speaker.name
      json.slug speaker.slug
    end
  end

  json.created_at @talk.created_at
  json.updated_at @talk.updated_at
end
