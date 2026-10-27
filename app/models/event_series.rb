# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: event_series
# Database name: primary
#
#  id                   :integer          not null, primary key
#  city                 :string
#  country_code         :string           indexed
#  description          :text             default(""), not null
#  frequency            :integer          default("unknown"), not null, indexed
#  kind                 :integer          default("conference"), not null, indexed
#  language             :string           default(""), not null
#  latitude             :decimal(10, 6)
#  location             :string           default(""), not null
#  longitude            :decimal(10, 6)
#  name                 :string           default(""), not null, indexed
#  slug                 :string           default(""), not null, indexed
#  state_code           :string
#  twitter              :string           default(""), not null
#  website              :string           default(""), not null
#  youtube_channel_name :string           default("")
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  parent_id            :integer          indexed
#  youtube_channel_id   :string           default("")
#
# Indexes
#
#  index_event_series_on_country_code  (country_code)
#  index_event_series_on_frequency     (frequency)
#  index_event_series_on_kind          (kind)
#  index_event_series_on_name          (name)
#  index_event_series_on_parent_id     (parent_id)
#  index_event_series_on_slug          (slug)
#
# Foreign Keys
#
#  parent_id  (parent_id => event_series.id)
#
# rubocop:enable Layout/LineLength
class EventSeries < ApplicationRecord
  include Sluggable
  include Todoable
  include EventSeries::TypesenseSearchable

  include ActionView::Helpers::TextHelper

  configure_slug(attribute: :name, auto_suffix_on_collision: false)

  # associations
  has_many :events, dependent: :destroy, inverse_of: :series, foreign_key: :event_series_id, strict_loading: true
  has_many :talks, through: :events
  has_many :aliases, as: :aliasable, class_name: "Alias", dependent: :destroy
  has_many :cfps, dependent: :destroy, class_name: "CFP"
  has_many :sponsors, dependent: :destroy
  has_many :event_involvements, dependent: :destroy
  belongs_to :parent, class_name: "EventSeries", optional: true, inverse_of: :children
  has_many :children, class_name: "EventSeries", foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify
  has_object :static_metadata

  # validations
  validates :name, presence: true

  # enums
  enum :kind, {conference: 0, meetup: 1, organisation: 2, retreat: 3, hackathon: 4, event: 5, workshop: 6}
  enum :frequency, {
    unknown: 0, yearly: 1, monthly: 2, biyearly: 3, quarterly: 4, irregular: 5, weekly: 6, biweekly: 7, bimonthly: 8
  }

  def self.find_by_name_or_alias(name)
    return nil if name.blank?

    series = find_by(name: name)
    return series if series

    alias_record = ::Alias.find_by(aliasable_type: "EventSeries", name: name)
    alias_record&.aliasable
  end

  def self.find_by_slug_or_alias(slug)
    return nil if slug.blank?

    series = find_by(slug: slug)
    return series if series

    alias_record = ::Alias.find_by(aliasable_type: "EventSeries", slug: slug)
    alias_record&.aliasable
  end

  def sync_aliases_from_list(alias_names)
    Array.wrap(alias_names).each do |alias_name|
      slug = alias_name.parameterize
      existing_own = aliases.find_by(name: alias_name) || aliases.find_by(slug: slug)

      if existing_own
        existing_own.update(name: alias_name) if existing_own.name != alias_name

        next
      end

      existing_global = ::Alias.find_by(aliasable_type: "EventSeries", name: alias_name) ||
        ::Alias.find_by(aliasable_type: "EventSeries", slug: slug)

      if existing_global
        existing_global.update!(aliasable: self) if alias_moved_here?(existing_global)

        next
      end

      next if ::Alias.exists?(slug: slug)

      aliases.create!(name: alias_name, slug: slug)
    end
  end

  def title
    %(All #{name} #{kind.pluralize})
  end

  def next_upcoming_event_with_tickets
    events.upcoming.find(&:tickets?)
  end

  def description
    non_cancelled = events.reject(&:cancelled?)

    if non_cancelled.empty?
      noun = meetup? ? "meetup" : "event"

      return "#{name} is a #{meetup? ? "meetup group" : kind}. We don't know of any of its #{noun.pluralize} yet.\n"
    end

    event_years = non_cancelled.filter_map { |e| (e.date || e.start_date || e.end_date)&.year }
    start_year = event_years.min
    end_year = event_years.max

    time_range = if start_year && start_year == end_year
      %( in #{start_year})
    elsif start_year && end_year
      %( between #{start_year} and #{end_year})
    else
      ""
    end

    event_type = pluralize(non_cancelled.size, meetup? ? "meetup" : "event")
    tense = (meetup? && inactive?) ? "was" : "is"
    frequency_text = if organisation?
      ""
    elsif unknown?
      "#{tense} a #{kind} that "
    else
      "#{tense} #{irregular? ? "an" : "a"} #{frequency} #{kind} and "
    end

    <<~DESCRIPTION
      #{name} #{frequency_text}hosted #{event_type}#{time_range}. We have currently indexed #{pluralize(non_cancelled.sum(&:talks_count), "#{name} talk")}.
    DESCRIPTION
  end

  def to_meta_tags
    event = events.order(date: :desc).first

    {
      title: title,
      description: description,
      og: {
        title: title,
        type: :website,
        image: {
          _: event ? Router.image_path(event.card_image_path) : nil,
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
          src: event ? Router.image_path(event.card_image_path) : nil
        }
      }
    }
  end

  def data_folder
    static_metadata.data_folder || Rails.root.join("data", slug)
  end

  scope :meetup_groups, -> { where(kind: :meetup).or(where(id: Event.where(kind: :meetup).select(:event_series_id))) }
  scope :searchable, -> { where(kind: :meetup).or(where(id: Event.select(:event_series_id))) }

  def meetups
    events.select { |event| event.meetup? && event.start_date.present? }.sort_by(&:start_date)
  end

  MEETUP_FREQUENCIES = [
    [10, :weekly],
    [21, :biweekly],
    [45, :monthly],
    [75, :bimonthly],
    [120, :quarterly],
    [240, :biyearly],
    [Float::INFINITY, :yearly]
  ].freeze

  MEETUP_FREQUENCY_PHRASES = {
    weekly: "weekly",
    biweekly: "every two weeks",
    monthly: "monthly",
    bimonthly: "every two months",
    quarterly: "quarterly",
    biyearly: "twice a year",
    yearly: "yearly",
    irregular: "irregularly"
  }.freeze

  def computed_meetup_frequency
    dates = meetups.reject(&:cancelled?).map(&:start_date).uniq.last(13)
    return nil if dates.size < 4

    gaps = dates.each_cons(2).map { |earlier, later| (later - earlier).to_i }
    median = gaps.sort[gaps.size / 2]
    mean = gaps.sum.to_f / gaps.size
    spread = Math.sqrt(gaps.sum { |gap| (gap - mean)**2 } / gaps.size) / mean

    return :irregular if spread > 1

    MEETUP_FREQUENCIES.find { |limit, _frequency| median <= limit }.last
  end

  def meetup_frequency
    MEETUP_FREQUENCY_PHRASES[computed_meetup_frequency]
  end

  INACTIVE_AFTER = 18.months

  def ended?
    static_metadata.ended?
  end

  def inactive?
    return true if ended?
    return false unless meetup? && next_meetup.nil?

    last_meetup.present? && last_meetup.start_date < INACTIVE_AFTER.ago.to_date
  end

  def meetup_frequency_sentence
    phrase = meetup_frequency
    return nil if phrase.nil?

    inactive? ? "Used to meet #{phrase}" : "Meets #{phrase}"
  end

  def next_meetup
    meetups.find { |event| event.start_date >= Date.today }
  end

  def last_meetup
    meetups.rfind { |event| event.start_date < Date.today }
  end

  def to_location
    @to_location ||= Location.from_record(self)
  end

  def ancestors
    parent ? [*parent.ancestors, parent] : []
  end

  def card_image_path = default_image_path("card.webp")
  def avatar_image_path = default_image_path("avatar.webp")
  def banner_image_path = default_image_path("banner.webp")

  def default_image_path(filename)
    file = static_metadata.default_image(filename)

    file ? file.relative_path_from(Rails.root.join("app/assets/images")).to_s : "events/default/#{filename}"
  end

  private

  # The YAML lists the alias here and no longer on the series that has it, like a conference's aliases after the
  # conference moved out of its old series into one of its own.
  def alias_moved_here?(alias_record)
    owner = alias_record.aliasable

    owner.is_a?(EventSeries) && owner != self && owner.static_metadata.aliases.exclude?(alias_record.name)
  end

  def todos_data_path
    data_folder
  end

  def todos_file_prefix
    data_folder.relative_path_from(Rails.root.join("data")).to_s
  end
end
