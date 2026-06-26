# == Schema Information
#
# Table name: event_check_ins
# Database name: primary
#
#  id            :integer          not null, primary key
#  checked_in_at :datetime         not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  connect_id    :string           not null, indexed, uniquely indexed => [event_id]
#  event_id      :integer          not null, uniquely indexed => [connect_id], indexed
#
# Indexes
#
#  index_event_check_ins_on_connect_id               (connect_id)
#  index_event_check_ins_on_connect_id_and_event_id  (connect_id,event_id) UNIQUE
#  index_event_check_ins_on_event_id                 (event_id)
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#
class EventCheckIn < ApplicationRecord
  # associations
  belongs_to :event

  belongs_to :passport,
    -> { passport },
    class_name: "ConnectedAccount",
    primary_key: :uid,
    foreign_key: :connect_id,
    optional: true,
    inverse_of: false

  has_one :user, through: :passport

  # validations
  validates :connect_id, presence: true, uniqueness: {scope: :event_id}
  validates :checked_in_at, presence: true

  # normalizations
  normalizes :connect_id, with: ->(value) { value.strip.upcase }

  def self.import_from_csv(event:, csv_content:)
    require "csv"

    created = 0
    skipped = 0
    errored = 0

    rows = CSV.parse(csv_content, headers: true)
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

    grouped.each do |connect_id, checked_in_at|
      existing = find_by(connect_id: connect_id, event: event)

      if existing
        skipped += 1
      else
        create!(connect_id: connect_id, event: event, checked_in_at: checked_in_at)
        created += 1
      end
    rescue
      errored += 1
    end

    {created: created, skipped: skipped, errored: errored}
  end
end
