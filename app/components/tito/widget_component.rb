# frozen_string_literal: true

class Tito::WidgetComponent < ApplicationComponent
  option :event
  option :wrapper, default: -> { true }

  def render?
    display && event.tickets.tito? && event.upcoming?
  end

  def event_slug
    event.tickets.tito_event_slug
  end
end
