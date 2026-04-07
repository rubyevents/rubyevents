# == Schema Information
#
# Table name: verified_event_participations
# Database name: primary
#
#  id         :integer          not null, primary key
#  scanned_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  connect_id :string           not null, indexed, uniquely indexed => [event_id]
#  event_id   :integer          not null, uniquely indexed => [connect_id], indexed
#
# Indexes
#
#  index_verified_event_participations_on_connect_id               (connect_id)
#  index_verified_event_participations_on_connect_id_and_event_id  (connect_id,event_id) UNIQUE
#  index_verified_event_participations_on_event_id                 (event_id)
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#
class VerifiedEventParticipation < ApplicationRecord
  # associations
  belongs_to :event

  # validations
  validates :connect_id, presence: true, uniqueness: {scope: :event_id}
  validates :scanned_at, presence: true

  # normalizations
  normalizes :connect_id, with: ->(value) { value.strip.upcase }

  def self.import_from_csv(event:, csv_content:)
    require "csv"

    created = 0
    skipped = 0
    errored = 0

    rows = CSV.parse(csv_content, headers: true)

    # Group by connect_id and keep earliest scanned_at
    grouped = {}
    rows.each do |row|
      connect_id = row["connect_id"]&.strip
      if connect_id.blank?
        errored += 1
        next
      end

      timestamp = begin
        Time.parse(row["created_at"])
      rescue ArgumentError, TypeError
        nil
      end

      if timestamp.nil?
        errored += 1
        next
      end

      key = connect_id.upcase
      if grouped[key].nil? || timestamp < grouped[key]
        grouped[key] = timestamp
      end
    end

    # Create records
    grouped.each do |connect_id, scanned_at|
      existing = find_by(connect_id: connect_id, event: event)
      if existing
        skipped += 1
      else
        create!(connect_id: connect_id, event: event, scanned_at: scanned_at)
        created += 1
      end
    rescue
      errored += 1
    end

    {created: created, skipped: skipped, errored: errored}
  end
end
