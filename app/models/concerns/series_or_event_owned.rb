# frozen_string_literal: true

# Records that belong to an event, or to a whole series like a meetup group's CFP, sponsors and organizers.
module SeriesOrEventOwned
  extend ActiveSupport::Concern

  included do
    belongs_to :event, optional: true
    belongs_to :event_series, optional: true

    validate :owned_by_event_or_series

    scope :for_series, -> { where.not(event_series_id: nil) }
  end

  def owner
    event || event_series
  end

  private

  def owned_by_event_or_series
    return if event_id.present? ^ event_series_id.present?

    errors.add(:base, "must belong to either an event or an event series")
  end
end
