# frozen_string_literal: true

# A role or sponsorship held between `started_on` and `ended_on`, either of which can be open.
# The YAML gives the bounds as "2018", "2018-06" or "2018-06-14": a start is the first day of its period, an end the last.
module Period
  extend ActiveSupport::Concern

  included do
    scope :active_on, ->(date) {
      where(started_on: nil).or(where(started_on: ..date)).merge(where(ended_on: nil).or(where(ended_on: date..)))
    }
  end

  class_methods do
    def period_start(value)
      parse_period(value)&.first
    end

    def period_end(value)
      parse_period(value)&.last
    end

    def parse_period(value)
      case value.to_s
      when /\A(\d{4})\z/
        year = $1.to_i
        Date.new(year, 1, 1)..Date.new(year, 12, 31)
      when /\A(\d{4})-(\d{2})\z/
        month = Date.new($1.to_i, $2.to_i, 1)
        month..month.end_of_month
      when /\A\d{4}-\d{2}-\d{2}\z/
        date = Date.parse(value.to_s)
        date..date
      end
    rescue Date::Error
      nil
    end
  end

  def active_on?(date)
    (started_on.nil? || started_on <= date) && (ended_on.nil? || ended_on >= date)
  end

  def period?
    started_on.present? || ended_on.present?
  end

  def current?
    ended_on.nil? || ended_on >= Date.current
  end

  # "2018 - 2022", "since Jun 2021", "until 2019"
  def period_label
    from = format_period_bound(started_on, :start)
    to = format_period_bound(ended_on, :end)

    if from && to
      (from == to) ? from : "#{from} - #{to}"
    elsif from
      "since #{from}"
    elsif to
      "until #{to}"
    end
  end

  private

  def format_period_bound(date, side)
    return nil unless date

    year_bound = (side == :start) ? date.beginning_of_year : date.end_of_year
    month_bound = (side == :start) ? date.beginning_of_month : date.end_of_month

    if date == year_bound
      date.year.to_s
    elsif date == month_bound
      date.strftime("%b %Y")
    else
      date.strftime("%b %-d, %Y")
    end
  end
end
