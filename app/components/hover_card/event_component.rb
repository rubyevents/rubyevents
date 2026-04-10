# frozen_string_literal: true

class HoverCard::EventComponent < HoverCard::BaseComponent
  def hover_card_url
    Router.hover_cards_event_path(slug: record.slug)
  end
end
