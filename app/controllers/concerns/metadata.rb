# frozen_string_literal: true

module Metadata
  extend ActiveSupport::Concern

  SITE_NAME = "RubyEvents.org"
  DEFAULT_TITLE = "#{SITE_NAME} - On a mission to index all Ruby events"
  DEFAULT_DESC = "On a mission to index all Ruby events. Your go-to place for talks and events about Ruby."
  DEFAULT_KEYWORDS = %w[ruby events conferences meetups]

  included do
    before_action :set_default_meta_tags
  end

  private

  def set_default_meta_tags
    set_meta_tags({
      title: DEFAULT_TITLE,
      canonical: request.original_url,
      description: DEFAULT_DESC,
      og: {
        title: DEFAULT_TITLE,
        url: request.original_url,
        description: DEFAULT_DESC,
        site_name: SITE_NAME,
        type: "website",
        image: view_context.image_url("logo_og_image.png")
      },
      twitter: {
        title: DEFAULT_TITLE,
        description: DEFAULT_DESC,
        card: "summary_large_image",
        image: view_context.image_url("logo_og_image.png")
      }
    })
  end
end
