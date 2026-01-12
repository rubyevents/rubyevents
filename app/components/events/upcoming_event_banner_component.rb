# frozen_string_literal: true

class Events::UpcomingEventBannerComponent < ApplicationComponent
  option :event, optional: true
  option :event_series, optional: true

  def render?
    upcoming_event.present? && should_show_banner?
  end

  def upcoming_event
    @upcoming_event ||= if event.present?
      event.next_upcoming_event_with_tickets
    elsif event_series.present?
      event_series.next_upcoming_event_with_tickets
    end
  end

  def background_style
    bg = upcoming_event.static_metadata.featured_background
    return bg unless bg.start_with?("data:")

    "url('#{bg}'); background-repeat: no-repeat; background-size: cover"
  end

  def background_color
    bg = upcoming_event.static_metadata.featured_background
    bg.start_with?("data:") ? "#000000" : bg
  end

  def text_color
    upcoming_event.static_metadata.featured_color
  end

  private

  def should_show_banner?
    if event.present?
      event.past?
    else
      true
    end
  end
end
