org_slug = ARGV[0]

organisations = YAML.load_file("#{Rails.root}/data/organisations.yml")
videos_to_ignore = YAML.load_file("#{Rails.root}/data/videos_to_ignore.yml")

org = organisations.detect { |o| o["slug"] == org_slug }

raise "uhoh #{org_slug} not present" if org.nil?

MeiliSearch::Rails.deactivate! do
  organisation = Organisation.find_or_initialize_by(slug: org["slug"])

  organisation.update!(
    name: org["name"],
    website: org["website"],
    twitter: org["twitter"] || "",
    youtube_channel_name: org["youtube_channel_name"],
    kind: org["kind"],
    frequency: org["frequency"],
    youtube_channel_id: org["youtube_channel_id"],
    slug: org["slug"],
    language: org["language"] || ""
  )

  events = YAML.load_file("#{Rails.root}/data/#{organisation.slug}/playlists.yml")

  events.each do |event_data|
    event = Event.find_or_create_by(slug: event_data["slug"])

    event.update(
      name: event_data["title"],
      date: event_data["date"] || event_data["published_at"],
      date_precision: event_data["date_precision"] || "day",
      organisation: organisation,
      website: event_data["website"],
      start_date: event.static_metadata.start_date,
      end_date: event.static_metadata.end_date,
      kind: event.static_metadata.kind,
      cfp_close_date: event_data["cfp_close_date"],
      cfp_link: event_data["cfp_link"],
      cfp_open_date: event_data["cfp_open_date"]
    )

    puts event.slug unless Rails.env.test?

    talks = YAML.load_file("#{Rails.root}/data/#{organisation.slug}/#{event.slug}/videos.yml")

    talks.each do |talk_data|
      if talk_data["title"].blank? || videos_to_ignore.include?(talk_data["video_id"])
        puts "Ignored video: #{talk_data["raw_title"]}"
        next
      end

      talk = Talk.find_by(video_id: talk_data["video_id"], video_provider: talk_data["video_provider"])
      talk = Talk.find_by(video_id: talk_data["video_id"]) if talk.blank?
      talk = Talk.find_by(video_id: talk_data["id"].to_s) if talk.blank?
      talk = Talk.find_by(slug: talk_data["slug"].to_s) if talk.blank?

      talk = Talk.find_or_initialize_by(video_id: talk_data["video_id"].to_s) if talk.blank?

      talk.video_provider = talk_data["video_provider"] || :youtube
      talk.update_from_yml_metadata!(event: event)

      child_talks = Array.wrap(talk_data["talks"])

      next if child_talks.none?

      child_talks.each do |child_talk_data|
        child_talk = Talk.find_by(video_id: child_talk_data["video_id"], video_provider: child_talk_data["video_provider"])
        child_talk = Talk.find_by(video_id: child_talk_data["video_id"]) if child_talk.blank?
        child_talk = Talk.find_by(video_id: child_talk_data["id"].to_s) if child_talk.blank?
        child_talk = Talk.find_by(slug: child_talk_data["slug"].to_s) if child_talk.blank?

        child_talk = Talk.find_or_initialize_by(video_id: child_talk_data["video_id"].to_s) if child_talk.blank?

        child_talk.video_provider = child_talk_data["video_provider"] || :parent
        child_talk.parent_talk = talk
        child_talk.update_from_yml_metadata!(event: event)
      end
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{talk_data["title"]} (#{talk_data["video_id"]}), error: #{e.message}"
    end
  end
end
