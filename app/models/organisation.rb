# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: organisations
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
#  youtube_channel_name :string           default(""), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  youtube_channel_id   :string           default(""), not null
#
# Indexes
#
#  index_organisations_on_frequency  (frequency)
#  index_organisations_on_kind       (kind)
#  index_organisations_on_name       (name)
#  index_organisations_on_slug       (slug)
#
# rubocop:enable Layout/LineLength
class Organisation < ApplicationRecord
  include Sluggable
  include Suggestable

  include ActionView::Helpers::TextHelper

  slug_from :name

  # associations
  has_many :events, dependent: :destroy, inverse_of: :organisation, foreign_key: :organisation_id, strict_loading: true
  has_many :talks, through: :events
  has_object :static_metadata

  # validations
  validates :name, presence: true

  # enums
  enum :kind, {conference: 0, meetup: 1, organisation: 2}
  enum :frequency, {unknown: 0, yearly: 1, monthly: 2, biyearly: 3, quarterly: 4, irregular: 5}

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
