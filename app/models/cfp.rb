# == Schema Information
#
# Table name: cfps
# Database name: primary
#
#  id         :integer          not null, primary key
#  close_date :date
#  link       :string
#  name       :string
#  open_date  :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer          not null, indexed
#
# Indexes
#
#  index_cfps_on_event_id  (event_id)
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#
class CFP < ApplicationRecord
  belongs_to :event

  scope :open, -> { where("close_date IS NULL OR close_date >= ?", Date.today) }
  scope :closed, -> { where("close_date < ?", Date.today) }
  scope :with_dates, -> { where.not(open_date: nil).where.not(close_date: nil) }

  def open?
    return false if closed?
    return false if future?

    open_ended? || close_date.present?
  end

  def open_ended?
    close_date.blank?
  end

  def closed?
    close_date.present? && Date.today > close_date
  end

  def future?
    open_date.present? && Date.today < open_date
  end

  def past?
    closed?
  end

  def status
    if future?
      :pending
    elsif open?
      :open
    else
      :closed
    end
  end

  def days_remaining
    return nil if close_date.blank?
    return nil if closed?

    (close_date - Date.today).to_i
  end

  def days_until_open
    return nil if open_date.blank?
    return nil if open?
    return nil if past?

    (open_date - Date.today).to_i
  end

  def days_since_close
    return nil if close_date.blank?
    return nil if future?
    return nil if open?

    (Date.current - close_date).to_i
  end

  def present?
    link.present?
  end

  def formatted_open_date
    I18n.l(open_date, default: "unknown")
  end

  def formatted_close_date
    I18n.l(close_date, default: "unknown")
  end

  def to_ical
    Icalendar::Event.new.tap do |cal_event|
      cal_event.uid = "RUBYEVENTS-CFP-#{id}"
      cal_event.last_modified = updated_at
      cal_event.dtstart = Icalendar::Values::Date.new(open_date)
      cal_event.dtend = Icalendar::Values::Date.new(close_date + 1.day)
      cal_event.summary = "#{event.name} - #{name.presence || "Call for Proposals"}"
      cal_event.url = link
    end
  end
end
