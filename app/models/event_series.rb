# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: event_series
# Database name: primary
#
#  id                   :integer          not null, primary key
#  description          :text             default(""), not null
#  frequency            :integer          default("unknown"), not null, indexed
#  kind                 :integer          default("conference"), not null, indexed
#  language             :string           default(""), not null
#  name                 :string           default(""), not null, indexed
#  slug                 :string           default(""), not null, indexed
#  twitter              :string           default(""), not null
#  website              :string           default(""), not null
#  youtube_channel_name :string           default("")
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  youtube_channel_id   :string           default("")
#
# Indexes
#
#  index_event_series_on_frequency  (frequency)
#  index_event_series_on_kind       (kind)
#  index_event_series_on_name       (name)
#  index_event_series_on_slug       (slug)
#
# rubocop:enable Layout/LineLength
class EventSeries < ApplicationRecord
  include Sluggable
  include Suggestable
  include EventSeries::TypesenseSearchable

  include ActionView::Helpers::TextHelper

  configure_slug(attribute: :name, auto_suffix_on_collision: false)

  # associations
  has_many :events, dependent: :destroy, inverse_of: :series, foreign_key: :event_series_id, strict_loading: true
  has_many :talks, through: :events
  has_many :aliases, as: :aliasable, class_name: "Alias", dependent: :destroy
  has_object :static_metadata

  # validations
  validates :name, presence: true

  # enums
  enum :kind, {conference: 0, meetup: 1, organisation: 2, retreat: 3, hackathon: 4, event: 5, workshop: 6}
  enum :frequency, {unknown: 0, yearly: 1, monthly: 2, biyearly: 3, quarterly: 4, irregular: 5}

  def self.find_by_name_or_alias(name)
    return nil if name.blank?

    series = find_by(name: name)
    return series if series

    alias_record = Alias.find_by(aliasable_type: "EventSeries", name: name)
    alias_record&.aliasable
  end

  def self.find_by_slug_or_alias(slug)
    return nil if slug.blank?

    series = find_by(slug: slug)
    return series if series

    alias_record = Alias.find_by(aliasable_type: "EventSeries", slug: slug)
    alias_record&.aliasable
  end

  def sync_aliases_from_list(alias_names)
    Array.wrap(alias_names).each do |alias_name|
      slug = alias_name.parameterize

      # Check if this alias already belongs to us
      existing_own = aliases.find_by(name: alias_name) || aliases.find_by(slug: slug)
      if existing_own
        existing_own.update(name: alias_name) if existing_own.name != alias_name
        next
      end

      # Check if alias exists globally for another EventSeries
      existing_global = Alias.find_by(aliasable_type: "EventSeries", name: alias_name) ||
        Alias.find_by(aliasable_type: "EventSeries", slug: slug)
      next if existing_global # Skip if it belongs to another series

      aliases.create!(name: alias_name, slug: slug)
    end
  end

  def title
    %(All #{name} #{kind.pluralize})
  end

  def description
    start_year = events.minimum(:date)&.year
    end_year = events.maximum(:date)&.year

    time_range = if start_year && start_year == end_year
      %( in #{start_year})
    elsif start_year && end_year
      %( between #{start_year} and #{end_year})
    else
      ""
    end

    event_type = pluralize(events.size, meetup? ? "event-series" : "event")
    frequency_text = (kind == "organisation") ? "" : " is a #{frequency} #{kind} and "

    <<~DESCRIPTION
      #{name} #{frequency_text}hosted #{event_type}#{time_range}. We have currently indexed #{pluralize(events.sum { |event| event.talks_count }, "#{name} talk")}.
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
end
