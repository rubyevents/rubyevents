# -*- SkipSchemaAnnotations

class Event::CFP < ActiveRecord::AssociatedObject
  def open?
    return false if closed?
    return false if future?

    close_date.present?
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

  def link
    event.cfp_link
  end

  def open_date
    event.cfp_open_date
  end

  def close_date
    event.cfp_close_date
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
