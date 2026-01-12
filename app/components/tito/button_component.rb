# frozen_string_literal: true

class Tito::ButtonComponent < ApplicationComponent
  option :event
  option :label, default: -> { "Tickets" }

  def render?
    display && event.tickets.available?
  end

  def classes
    "btn btn-primary btn-sm w-full no-animation"
  end
end
