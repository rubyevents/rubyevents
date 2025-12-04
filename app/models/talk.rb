# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: talks
# Database name: primary
#
#  id                  :integer          not null, primary key
#  announced_at        :datetime
#  date                :date             indexed, indexed => [video_provider]
#  description         :text             default(""), not null
#  duration_in_seconds :integer
#  end_seconds         :integer
#  external_player     :boolean          default(FALSE), not null
#  external_player_url :string           default(""), not null
#  kind                :string           default("talk"), not null, indexed
#  language            :string           default("en"), not null
#  like_count          :integer          default(0)
#  meta_talk           :boolean          default(FALSE), not null
#  original_title      :string           default(""), not null
#  published_at        :datetime
#  slides_url          :string
#  slug                :string           default(""), not null, indexed
#  start_seconds       :integer
#  summarized_using_ai :boolean          default(TRUE), not null
#  summary             :text             default(""), not null
#  thumbnail_lg        :string           default(""), not null
#  thumbnail_md        :string           default(""), not null
#  thumbnail_sm        :string           default(""), not null
#  thumbnail_xl        :string           default(""), not null
#  thumbnail_xs        :string           default(""), not null
#  title               :string           default(""), not null, indexed
#  video_provider      :string           default("youtube"), not null, indexed => [date]
#  view_count          :integer          default(0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null, indexed
#  event_id            :integer          indexed
#  parent_talk_id      :integer          indexed
#  static_id           :string           not null, uniquely indexed
#  video_id            :string           default(""), not null
#
# Indexes
#
#  index_talks_on_date                     (date)
#  index_talks_on_event_id                 (event_id)
#  index_talks_on_kind                     (kind)
#  index_talks_on_parent_talk_id           (parent_talk_id)
#  index_talks_on_slug                     (slug)
#  index_talks_on_static_id                (static_id) UNIQUE
#  index_talks_on_title                    (title)
#  index_talks_on_updated_at               (updated_at)
#  index_talks_on_video_provider_and_date  (video_provider,date)
#
# Foreign Keys
#
#  event_id        (event_id => events.id)
#  parent_talk_id  (parent_talk_id => talks.id)
#
# rubocop:enable Layout/LineLength
class Talk < ApplicationRecord
  include Rollupable
  include Sluggable
  include Suggestable
  include Searchable
  include Watchable

  configure_slug(attribute: :title, auto_suffix_on_collision: true)

  # associations
  belongs_to :event, optional: true, counter_cache: :talks_count, touch: true
  belongs_to :parent_talk, optional: true, class_name: "Talk", foreign_key: :parent_talk_id

  has_many :child_talks, class_name: "Talk", foreign_key: :parent_talk_id, dependent: :destroy
  has_many :child_talks_speakers, -> { distinct }, through: :child_talks, source: :users, class_name: "User"
  has_many :kept_child_talks_speakers, -> { distinct }, through: :child_talks, source: :kept_speakers,
    class_name: "User"
  # User associations (for merged Speaker functionality)
  has_many :user_talks, dependent: :destroy, inverse_of: :talk, foreign_key: :talk_id
  has_many :kept_user_talks, -> { kept }, dependent: :destroy, inverse_of: :talk, foreign_key: :talk_id,
    class_name: "UserTalk"
  has_many :users, through: :user_talks, inverse_of: :talks
  has_many :speakers, -> { where("users.talks_count > 0") }, through: :user_talks, inverse_of: :talks, source: :user
  has_many :kept_speakers, -> { where("users.talks_count > 0") }, through: :kept_user_talks, inverse_of: :talks,
    class_name: "User", source: :user

  has_many :talk_topics, dependent: :destroy
  has_many :topics, through: :talk_topics
  has_many :approved_topics, -> { approved }, through: :talk_topics, source: :topic, inverse_of: :talks

  has_many :watch_list_talks, dependent: :destroy
  has_many :watch_lists, through: :watch_list_talks

  has_many :aliases, as: :aliasable, dependent: :destroy

  has_one :talk_transcript, class_name: "Talk::Transcript", dependent: :destroy
  accepts_nested_attributes_for :talk_transcript
  delegate :transcript, :raw_transcript, :enhanced_transcript, to: :talk_transcript, allow_nil: true

  # associated objects
  has_object :agents
  has_object :downloader
  has_object :thumbnails

  # validations
  validates :title, presence: true
  validates :language, presence: true,
    inclusion: {in: Language.alpha2_codes, message: "%{value} is not a valid IS0-639 alpha2 code"}

  validates :date, presence: true
  # validates :published_at, presence: true, if: :published? # TODO: enable
  validate :parent_talk_id_cannot_be_self

  # delegates
  delegate :name, to: :event, prefix: true, allow_nil: true

  # callbacks
  before_validation :set_kind, if: -> { !kind_changed? }

  WATCHABLE_PROVIDERS = ["youtube", "mp4", "vimeo"]

  # enums
  enum :video_provider, %w[youtube mp4 vimeo scheduled not_published not_recorded parent children].index_by(&:itself)

  attribute :kind, :string
  enum :kind,
    %w[keynote talk lightning_talk panel workshop gameshow podcast q_and_a discussion fireside_chat
      interview award].index_by(&:itself)

  def self.speaker_role_titles
    {
      keynote: "Keynote Speaker",
      talk: "Speaker",
      lightning_talk: "Lightning Talk Speaker",
      panel: "Panelist",
      discussion: "Panelist",
      gameshow: "Game Show Host",
      workshop: "Workshop Instructor",
      podcast: "Podcast Host/Participant",
      q_and_a: "Q&A Host/Participant",
      fireside_chat: "Fireside Chat Host/Participant",
      interview: "Interviewer/Interviewee",
      award: "Award Presenter/Winner"
    }
  end

  def self.find_by_slug_or_alias(slug)
    return nil if slug.blank?

    talk = find_by(slug: slug)
    return talk if talk

    alias_record = Alias.find_by(aliasable_type: "Talk", slug: slug)
    alias_record&.aliasable
  end

  def formatted_kind
    case kind
    when "keynote" then "Keynote"
    when "talk" then "Talk"
    when "lightning_talk" then "Lightning Talk"
    when "panel" then "Panel"
    when "workshop" then "Workshop"
    when "gameshow" then "Gameshow"
    when "podcast" then "Podcast"
    when "q_and_a" then "Q&A"
    when "discussion" then "Discussion"
    when "fireside_chat" then "Fireside Chat"
    when "interview" then "Interview"
    when "award" then "Award"
    else raise "`#{kind}` not defined in `Talk#formatted_kind`"
    end
  end

  # attributes
  attribute :video_provider, default: :youtube

  # jobs
  performs :update_from_yml_metadata!
  performs :fetch_and_update_raw_transcript!, retries: 3
  performs :fetch_duration_from_youtube!

  # normalization
  normalizes :language, apply_to_nil: true, with: ->(language) do
    language.present? ? Language.find(language)&.alpha2 : Language::DEFAULT
  end

  # ensure that during the reindex process the associated records are eager loaded
  scope :without_raw_transcript, -> {
    joins(:talk_transcript)
      .where(%(
        talk_transcripts.raw_transcript IS NULL
        OR talk_transcripts.raw_transcript = ''
        OR talk_transcripts.raw_transcript = '[]'
      ))
  }
  scope :with_raw_transcript, -> {
    joins(:talk_transcript)
      .where(%(
        talk_transcripts.raw_transcript IS NOT NULL
        AND talk_transcripts.raw_transcript != '[]'
      ))
  }
  scope :without_enhanced_transcript,
    -> {
      joins(:talk_transcript)
        .where(%(
          talk_transcripts.enhanced_transcript IS NULL
          OR talk_transcripts.enhanced_transcript = ''
          OR talk_transcripts.enhanced_transcript = '[]'
        ))
    }
  scope :with_enhanced_transcript, -> {
    joins(:talk_transcript)
      .where(%(
        talk_transcripts.enhanced_transcript IS NOT NULL
        AND talk_transcripts.enhanced_transcript != '[]'
      ))
  }
  scope :with_summary, -> { where("summary IS NOT NULL AND summary != ''") }
  scope :without_summary, -> { where("summary IS NULL OR summary = ''") }
  scope :without_topics, -> { where.missing(:talk_topics) }
  scope :with_topics, -> { joins(:talk_topics) }
  scope :with_speakers, -> { joins(:user_talks).distinct }
  scope :for_topic, ->(topic_slug) { joins(:topics).where(topics: {slug: topic_slug}) }
  scope :for_speaker, ->(speaker_slug) { joins(:users).where(users: {slug: speaker_slug}) }
  scope :for_event, ->(event_slug) { joins(:event).where(events: {slug: event_slug}) }
  scope :scheduled, -> { where(video_provider: "scheduled") }
  scope :watchable, -> { where(video_provider: WATCHABLE_PROVIDERS) }
  scope :youtube, -> { where(video_provider: "youtube") }
  scope :upcoming, -> { where(date: Date.today...) }
  scope :today, -> { where(date: Date.today) }
  scope :past, -> { where(date: ...Date.today) }

  def managed_by?(visiting_user)
    return false unless visiting_user.present?
    return true if visiting_user.admin?

    users.exists?(id: visiting_user.id)
  end

  def published?
    video_provider.in?(WATCHABLE_PROVIDERS) || parent_talk&.published?
  end

  def to_meta_tags
    {
      title: title,
      description: description,
      og: {
        title: title,
        type: :website,
        image: {
          _: thumbnail_xl,
          alt: title
        },
        description: description,
        site_name: "RubyEvents.org"
      },
      twitter: {
        card: "summary_large_image",
        site: "@rubyevents_org",
        title: title,
        description: description,
        image: {
          src: thumbnail_xl
        }
      }
    }
  end

  def thumbnail_xs
    thumbnail(:thumbnail_xs)
  end

  def thumbnail_sm
    thumbnail(:thumbnail_sm)
  end

  def thumbnail_md
    thumbnail(:thumbnail_md)
  end

  def thumbnail_lg
    thumbnail(:thumbnail_lg)
  end

  def thumbnail_xl
    thumbnail(:thumbnail_xl)
  end

  def thumbnail_classes
    static_metadata.try(:[], "thumbnail_classes") || ""
  end

  def fallback_thumbnail
    "/assets/#{Rails.application.assets.load_path.find("events/default/poster.webp").digested_path}"
  end

  def thumbnail_url(size:, request:)
    url = thumbnail(size)

    if url.starts_with?("http")
      return url
    end

    "#{request.protocol}#{request.host}:#{request.port}/#{url}"
  end

  def thumbnail(size = :thumbnail_lg)
    if self[size].present?
      return self[size] if self[size].start_with?("https://")

      if (asset = Rails.application.assets.load_path.find(self[size]))
        return "/assets/#{asset.digested_path}"
      end
    end

    if (asset = Rails.application.assets.load_path.find("thumbnails/#{video_id}.webp"))
      return "/assets/#{asset.digested_path}"
    end

    if vimeo?
      vimeo = {
        thumbnail_xs: "_small",
        thumbnail_sm: "_small",
        thumbnail_md: "_medium",
        thumbnail_lg: "_large",
        thumbnail_xl: "_large"
      }

      return "https://vumbnail.com/#{video_id}#{vimeo[size]}.jpg"
    end

    if youtube?
      youtube = {
        thumbnail_xs: "default",
        thumbnail_sm: "mqdefault",
        thumbnail_md: "hqdefault",
        thumbnail_lg: "sddefault",
        thumbnail_xl: "maxresdefault"
      }

      return "https://i.ytimg.com/vi/#{video_id}/#{youtube[size]}.jpg"
    end

    if video_provider == "parent" && parent_talk.present?
      return parent_talk.thumbnail(size)
    end

    if event && (asset = Rails.application.assets.load_path.find(event.poster_image_path))
      return "/assets/#{asset.digested_path}"
    end

    fallback_thumbnail
  end

  def external_player_utm_params
    {
      utm_source: "rubyevents.org",
      utm_medium: "referral",
      utm_campaign: event.slug,
      utm_content: slug
    }
  end

  def external_player_url
    uri = URI.parse(self[:external_player_url].presence || provider_url)

    existing_params = URI.decode_www_form(uri.query || "").to_h
    updated_params = existing_params.merge(external_player_utm_params)

    uri.query = URI.encode_www_form(updated_params)

    uri.to_s
  end

  def provider_url
    case video_provider
    when "youtube"
      "https://www.youtube.com/watch?v=#{video_id}"
    when "mp4"
      video_id
    when "vimeo"
      "https://vimeo.com/video/#{video_id}"
    when "parent"
      timestamp = ""

      if parent_talk.video_provider == "vimeo"
        timestamp = start_seconds ? "#t=#{start_seconds}" : ""
      elsif parent_talk.video_provider == "youtube"
        timestamp = start_seconds ? "&t=#{start_seconds}" : ""
      end

      "#{parent_talk.provider_url}#{timestamp}"
    else
      "#"
    end
  end

  def related_talks(limit: 6)
    ids = Rails.cache.fetch(["talk_recommendations", id, limit], expires_in: 1.week) do
      Talk.order("RANDOM()").excluding(self).limit(limit).ids
    end

    Talk.includes(event: :series).where(id: ids)
  end

  def formatted_date
    I18n.l(date, default: "unknown")
  end

  def formatted_duration
    Duration.seconds_to_formatted_duration(duration)
  end

  def duration
    return nil if start_seconds.blank? || end_seconds.blank?

    ActiveSupport::Duration.build(end_seconds - start_seconds)
  end

  def speakers
    return super unless meta_talk

    child_talks_speakers
  end

  def speaker_names
    speakers.pluck(:name).join(" ")
  end

  def event_names
    return "" unless event

    names = [event.name]
    names += event.slug_aliases.pluck(:name)

    if event.series
      names << event.series.name
      names += event.series.aliases.pluck(:name)
    end

    names.compact.uniq.join(" ")
  end

  def language_name
    Language.by_code(language)
  end

  def location
    static_metadata.try(:location) || event.static_metadata.location
  end

  def slug_candidates
    @slug_candidates ||= [
      static_metadata.slug&.parameterize,
      title.parameterize,
      [title.parameterize, event&.name&.parameterize].compact.reject(&:blank?).join("-"),
      [title.parameterize, language&.parameterize].compact.reject(&:blank?).join("-"),
      [title.parameterize, event&.name&.parameterize, language&.parameterize].compact.reject(&:blank?).join("-"),
      [date.to_s.parameterize, title.parameterize].compact.reject(&:blank?).join("-"),
      [title.parameterize, *speakers.map(&:slug)].compact.reject(&:blank?).join("-"),
      [static_metadata.raw_title.parameterize].compact.reject(&:blank?).join("-"),
      [date.to_s.parameterize, static_metadata.raw_title.parameterize].compact.reject(&:blank?).join("-")
    ].reject(&:blank?).uniq
  end

  def unused_slugs
    used_slugs = Talk.excluding(self).where(slug: slug_candidates).pluck(:slug)
    used_alias_slugs = Alias.where(aliasable_type: "Talk", slug: slug_candidates)
      .where.not(aliasable_id: id)
      .pluck(:slug)
    slug_candidates - used_slugs - used_alias_slugs
  end

  def event_name
    return event.name unless event.meetup?

    static_metadata.try("event_name") || event.name
  end

  def fetch_and_update_raw_transcript!
    youtube_transcript = YouTube::Transcript.get(video_id)
    transcript = talk_transcript || Talk::Transcript.new(talk: self)
    transcript.update!(raw_transcript: ::Transcript.create_from_youtube_transcript(youtube_transcript))
  end

  def fetch_duration_from_youtube!
    return unless youtube?

    duration_seconds = YouTube::Video.new.duration(video_id)
    update duration_in_seconds: duration_seconds
  end

  def update_from_yml_metadata!(event: nil)
    if event.blank?
      event = Event.find_by(name: static_metadata.event_name)

      if event.nil?
        puts "No event found! Video ID: #{video_id}, Event: #{static_metadata.event_name}"
        return
      end
    end

    no_speakers = Array.wrap(static_metadata.speakers).none?
    no_talks = Array.wrap(static_metadata.talks).none?
    meta_talk = static_metadata.meta_talk?

    if static_metadata.blank? || (no_speakers && no_talks && !meta_talk)
      puts "No speakers for Video ID: #{video_id}"
      return
    end

    assign_attributes(
      event: event,
      static_id: static_metadata.id,
      title: static_metadata.title,
      original_title: static_metadata.original_title || "",
      description: static_metadata.description,
      date: static_metadata.try(:date) || parent_talk&.static_metadata.try(:date),
      published_at: static_metadata.try(:published_at) || parent_talk&.static_metadata.try(:published_at),
      announced_at: static_metadata.try(:announced_at) || parent_talk&.static_metadata.try(:announced_at),
      thumbnail_xs: static_metadata["thumbnail_xs"] || "",
      thumbnail_sm: static_metadata["thumbnail_sm"] || "",
      thumbnail_md: static_metadata["thumbnail_md"] || "",
      thumbnail_lg: static_metadata["thumbnail_lg"] || "",
      thumbnail_xl: static_metadata["thumbnail_xl"] || "",
      language: static_metadata.language || Language::DEFAULT,
      slides_url: static_metadata.slides_url,
      video_id: static_metadata.video_id,
      video_provider: static_metadata.video_provider,
      external_player: static_metadata.external_player || false,
      external_player_url: static_metadata.external_player_url || "",
      meta_talk: static_metadata.meta_talk?,
      start_seconds: static_metadata.start_cue_in_seconds,
      end_seconds: static_metadata.end_cue_in_seconds
    )

    self.kind = static_metadata.kind if static_metadata.try(:kind).present?

    self.speakers = Array.wrap(static_metadata.speakers).reject(&:blank?).map { |speaker_name|
      User.find_by_name_or_alias(speaker_name.strip) ||
        User.find_by(slug: speaker_name.parameterize) ||
        User.find_or_create_by(name: speaker_name.strip)
    }

    new_slug = unused_slugs.first

    if slug.present? && slug != new_slug
      aliases.find_or_create_by!(name: title, slug: slug)
    end

    self.slug = new_slug

    save!
  end

  def static_metadata
    @static_metadata ||= Static::Video.find_by_static_id(static_id)
  end

  def suggestion_summary
    <<~HEREDOC
      Talk: #{title} (#{date})
      by #{speakers.map(&:name).to_sentence}
      at #{event.name}
    HEREDOC
  end

  def set_kind
    if static_metadata && static_metadata.kind.present?
      unless static_metadata.kind.in?(Talk.kinds.keys)
        puts %(WARN: "#{title}" has an unknown talk kind defined in #{static_metadata.__file_path})
      end

      self.kind = static_metadata.kind
      return
    end

    self.kind = case title
    when /^(keynote:|keynote|opening\ keynote:|opening\ keynote|closing\ keynote:|closing\ keynote).*/i
      :keynote
    when /^(lightning\ talk:|lightning\ talk|lightning\ talks|micro\ talk:|micro\ talk).*/i
      :lightning_talk
    when /.*(panel:|panel).*/i
      :panel
    when /^(workshop:|workshop).*/i
      :workshop
    when /^(gameshow|game\ show|gameshow:|game\ show:).*/i
      :gameshow
    when /^(podcast:|podcast\ recording:|live\ podcast:).*/i
      :podcast
    when /.*(q&a|q&a:|q&a\ with|ruby\ committers\ vs\ the\ world|ruby\ committers\ and\ the\ world).*/i,
        /.*(AMA)$/,
        /^(AMA:)/
      :q_and_a
    when /^(fishbowl:|fishbowl\ discussion:|discussion:|discussion).*/i
      :discussion
    when /^(fireside\ chat:|fireside\ chat).*/i
      :fireside_chat
    when /^(award:|award\ show|ruby\ heroes\ awards|ruby\ heroes\ award|rails\ luminary).*/i
      :award
    when /^(interview:|interview\ with).*/i
      :interview
    else
      :talk
    end
  end

  def to_mobile_json(request)
    {
      id: id,
      title: title,
      duration_in_seconds: duration_in_seconds,
      slug: slug,
      event_name: event_name,
      thumbnail_url: thumbnail_url(size: :thumbnail_sm, request: request),
      speakers: speakers.map { |speaker| speaker.to_mobile_json(request) },
      url: Router.talk_url(self, host: "#{request.protocol}#{request.host}:#{request.port}")
    }
  end

  private

  def parent_talk_id_cannot_be_self
    return if parent_talk_id.nil?

    if parent_talk_id == id
      errors.add(:parent_talk_id, "cannot be the same as the talk itself")
    end
  end
end
