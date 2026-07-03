module TalksHelper
  def seconds_to_formatted_duration(seconds)
    Duration.seconds_to_formatted_duration(seconds, raise: false)
  end

  def talk_watch_status(talk)
    if talk.scheduled? || talk.parent_talk&.scheduled?
      {label: "Scheduled", icon: "clock"}
    elsif talk.not_recorded? || talk.parent_talk&.not_recorded?
      {label: "Not Recorded", icon: "video-slash"}
    elsif talk.not_published? || talk.parent_talk&.not_published?
      {label: "Not Published", icon: "upload"}
    elsif talk.video_unavailable?
      {label: "Unavailable", icon: "video-slash"}
    end
  end

  def ordering_title
    case order_by_key
    when "date_desc"
      "Newest first"
    when "date_asc"
      "Oldest first"
    when "ranked"
      "Relevance"
    end
  end

  def resource_icon(resource)
    case resource["type"]
    when "write-up", "blog", "article" then "pen-to-square"
    when "source-code", "code", "repo" then "code"
    when "github" then "github"
    when "documentation", "docs" then "book"
    when "slides", "presentation" then "presentation-screen"
    when "video" then "video"
    when "podcast", "audio" then "podcast"
    when "gem", "library" then "gem"
    when "transcript" then "file-lines"
    when "handout" then "file-pdf"
    when "notes" then "note-sticky"
    when "photos" then "images"
    when "book" then "book"
    else "link"
    end
  end

  def resource_display_title(resource)
    resource["title"].presence || resource["name"]
  end

  def resource_domain(resource)
    URI.parse(resource["url"]).host
  rescue URI::InvalidURIError
    resource["url"]
  end

  def transcript_language_label(talk_transcript)
    name = Language.find(talk_transcript.language)&.english_name || talk_transcript.language.upcase
    talk_transcript.auto_generated ? "#{name} (auto-generated)" : name
  end

  def transcript_shows_hours?(cue_list)
    cue_list.cues.last&.start_time_in_seconds.to_i >= 3600
  end

  def dummy_talk_mentions(talk)
    random = Arel.sql("RANDOM()")
    topics = Topic.canonical.order(random).limit(2).to_a
    keynote_speaker = talk.event&.talks&.where(kind: "keynote")&.first&.speakers&.first
    post_speaker = User.speakers.with_github.where.not(id: talk.speaker_ids).order(random).first
    related_talk = Talk.where.not(id: talk.id).where.not(thumbnail_sm: "").order(random).first
    event = Event.where(kind: "conference").where("start_date >= ?", 3.years.ago.to_date).order(random).first

    mentions = []
    mentions << {kind: :topic, record: topics[0], time: "9:25", start: 565, surface: "so we lean on #{topics[0].name} for a lot of this", status: :verified} if topics[0]
    mentions << {kind: :person, record: keynote_speaker, time: "21:03", start: 1263, surface: "like #{keynote_speaker.name.split(" ").first} showed in the keynote yesterday", status: :potential} if keynote_speaker
    mentions << {kind: :talk, record: related_talk, time: "30:10", start: 1810, surface: "there's a great talk on exactly this, definitely go watch it", status: :verified} if related_talk
    mentions << {kind: :event, record: event, time: "37:40", start: 2260, surface: "we first showed this off at #{event.name}", status: :verified} if event
    mentions << {kind: :link, url: "https://github.com/rails/rails", label: "github.com/rails/rails", time: "40:02", start: 2402, surface: "the code is all up at github dot com slash rails", status: :verified}
    mentions << {kind: :person, label: "Alan Kay", time: "44:20", start: 2660, surface: "which goes right back to what Alan Kay meant by objects", status: :potential}
    mentions << {kind: :person, record: post_speaker, time: "55:55", start: 3355, surface: "#{post_speaker.name.split(" ").first} wrote a great post about this", status: :potential} if post_speaker
    mentions
  end

  def mention_link(mention)
    case mention[:kind]
    when :topic then mention[:record] && topic_path(mention[:record])
    when :person then mention[:record] && profile_path(mention[:record])
    when :talk then mention[:record] && talk_path(mention[:record])
    when :event then mention[:record] && event_path(mention[:record])
    else mention[:url]
    end
  end

  def mention_title(mention)
    record = mention[:record]
    record&.try(:title) || record&.try(:name) || mention[:label]
  end

  OffPlatformPerson = Struct.new(:name) do
    def custom_avatar? = false
  end

  def mention_avatarable(mention)
    mention[:record] || OffPlatformPerson.new(mention_title(mention))
  end

  def mention_theme(kind)
    {
      topic: {pill: "text-indigo-700 bg-indigo-100", ring: "ring-indigo-200"},
      person: {pill: "text-purple-700 bg-purple-100", ring: "ring-purple-200"},
      talk: {pill: "text-blue-700 bg-blue-100", ring: "ring-blue-200"},
      event: {pill: "text-orange-700 bg-orange-100", ring: "ring-orange-200"},
      link: {pill: "text-teal-700 bg-teal-100", ring: "ring-teal-200"}
    }.fetch(kind, {pill: "text-gray-700 bg-gray-100", ring: "ring-gray-200"})
  end

  def formatted_cue_timestamp(cue, show_hours:)
    minutes, seconds = cue.start_time_in_seconds.divmod(60)

    if show_hours
      hours, minutes = minutes.divmod(60)
      format("%d:%02d:%02d", hours, minutes, seconds)
    else
      format("%02d:%02d", minutes, seconds)
    end
  end
end
