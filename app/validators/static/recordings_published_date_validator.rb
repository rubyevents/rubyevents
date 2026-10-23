# frozen_string_literal: true

module Static
  # recordings_published_date is set once the majority of an event's talks are published, and not
  # before the event, nor before the P90 of the videos' published_at dates. That meetups and events
  # that haven't started don't have one is validated on Static::Event.
  #
  class RecordingsPublishedDateValidator < ActiveModel::Validator
    WATCHABLE_PROVIDERS = %w[youtube mp4 vimeo].freeze
    TERMINAL_PROVIDERS = %w[not_recorded not_published].freeze
    PERCENTILE = 90

    def self.percentile(dates, percentile = PERCENTILE)
      return nil if dates.empty?

      sorted = dates.sort
      rank = (percentile / 100.0 * sorted.size).ceil

      sorted[[rank - 1, 0].max]
    end

    def validate(event)
      value = event["recordings_published_date"]
      talks = event.talks.top_level
      watchable = talks.where(video_provider: WATCHABLE_PROVIDERS).count
      resolvable = talks.where.not(video_provider: TERMINAL_PROVIDERS).count
      majority_published = resolvable.positive? && watchable * 2 > resolvable
      counts = "(#{watchable}/#{resolvable} resolvable talks published)"

      if value.blank?
        add(event, "is required when the majority of talks are published #{counts}") if majority_published
      elsif !majority_published
        add(event, "(#{value}) must not be set unless the majority of talks are published #{counts}")
      else
        validate_not_too_early(event, talks, value)
      end
    end

    private

    def validate_not_too_early(event, talks, value)
      published_date = parse_date(value)
      return unless published_date

      %w[start_date end_date].each do |field|
        date = parse_date(event[field])
        add(event, "(#{value}) must not be before #{field} (#{event[field]})") if date && published_date < date
      end

      reference_date = self.class.percentile(talks.filter_map { |talk| parse_date(talk.published_at) })

      if reference_date && published_date < reference_date
        add(event, "(#{value}) must not be before the P#{PERCENTILE} of the video published_at dates (#{reference_date})")
      end
    end

    def add(event, message)
      event.errors.add(:recordings_published_date, message)
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue Date::Error, TypeError
      nil
    end
  end
end
