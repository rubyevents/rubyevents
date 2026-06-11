# == Schema Information
#
# Table name: cfps
# Database name: primary
#
#  id         :integer          not null, primary key
#  close_date :datetime
#  link       :string
#  name       :string
#  open_date  :datetime
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

  scope :open, -> { where("close_date IS NULL OR close_date >= ?", Date.today.in_time_zone) }
  scope :closed, -> { where("close_date < ?", Date.today.in_time_zone) }

  def open?
    return false if closed?
    return false if future?

    open_ended? || close_date.present?
  end

  def open_ended?
    close_date.blank?
  end

  def closed?
    close_date.present? && Date.today.in_time_zone > close_date
  end

  def future?
    open_date.present? && Date.today.in_time_zone < open_date
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

    diff_in_seconds = (close_date - Date.today.in_time_zone).to_i
    (diff_in_seconds / 1.day).round
  end

  def days_until_open
    return nil if open_date.blank?
    return nil if open?
    return nil if past?

    diff_in_seconds = (open_date - Date.today.in_time_zone).to_i
    (diff_in_seconds / 1.day).round
  end

  def days_since_close
    return nil if close_date.blank?
    return nil if future?
    return nil if open?

    diff_in_seconds = (DateTime.current.in_time_zone - close_date).to_i

    (diff_in_seconds / 1.day).round
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
end
