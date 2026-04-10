# frozen_string_literal: true

class HoverCard::UserComponent < HoverCard::BaseComponent
  def hover_card_url
    Router.hover_cards_user_path(slug: record.slug, avatar_size: avatar_size)
  end

  def render?
    super && !record.suspicious?
  end
end
