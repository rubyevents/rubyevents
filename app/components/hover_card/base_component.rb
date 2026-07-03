# frozen_string_literal: true

class HoverCard::BaseComponent < ViewComponent::Base
  include Turbo::FramesHelper

  attr_reader :record, :avatar_size

  def initialize(record:, avatar_size: :sm)
    @record = record
    @avatar_size = avatar_size
  end

  def frame_id
    dom_id(record, :hover_card)
  end

  def hover_card_url
    raise NotImplementedError, "Subclasses must implement #hover_card_url"
  end

  def render?
    record.present?
  end
end
