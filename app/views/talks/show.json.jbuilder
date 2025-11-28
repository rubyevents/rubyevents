json.talk do
  json.slug @talk.slug
  json.title @talk.title
  json.original_title @talk.original_title
  json.description @talk.description
  json.summary @talk.summary
  json.date @talk.date
  json.kind @talk.kind
  json.video_provider @talk.video_provider
  json.video_id @talk.video_id
  json.slides_url @talk.slides_url

  if @talk.event.present?
    json.event do
      json.slug @talk.event.slug
      json.name @talk.event.name
      json.start_date @talk.event.start_date
      json.end_date @talk.event.end_date

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

  json.created_at @talk.created_at
  json.updated_at @talk.updated_at
end
