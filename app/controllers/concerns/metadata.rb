module Metadata
  extend ActiveSupport::Concern

  included do
    before_action :set_default_meta_tags
  end

  private

  def set_default_meta_tags
    set_meta_tags({
      description: "On a mission to index all Ruby events. Your go-to place for talks and events about Ruby."
    })
  end
end
