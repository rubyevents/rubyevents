# frozen_string_literal: true

class Ui::SocialLinksComponent < ApplicationComponent
  Platform = Data.define(:field, :label, :icon, :hover, :url)

  VARIANT_MAPPING = {
    circle: "gap-2",
    inline: "gap-3"
  }.freeze

  INLINE_CLASS = "inline-flex items-center justify-center size-6 box-content p-2 -m-2 text-gray-400 hover:text-gray-900 rounded focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary focus-visible:text-gray-900"

  PLATFORMS = [
    {field: "bsky", label: "Bluesky", icon: "bluesky", hover: "hover:bg-[#0085FF] hover:fill-white border-base-200", url: ->(v) { "https://bsky.app/profile/#{v}" }},
    {field: "facebook", label: "Facebook", icon: "facebook", hover: "hover:bg-[#1877F2] hover:fill-white border-base-200", url: ->(v) { v }},
    {field: "github", label: "GitHub", icon: "github", hover: "hover:bg-black hover:fill-white border-base-200", url: ->(v) { "https://github.com/#{v}" }},
    {field: "linkedin", label: "LinkedIn", icon: "linkedin", hover: "hover:bg-[#0A66C2] hover:fill-white border-base-200", url: ->(v) { "https://www.linkedin.com/in/#{v}" }},
    {field: "mastodon", label: "Mastodon", icon: "mastodon", hover: "hover:bg-[#6364FF] hover:fill-white border-base-200", url: ->(v) { v }},
    {field: "meetup", label: "Meetup", icon: "meetup", hover: "hover:bg-[#ED1C40] hover:fill-white border-base-200", url: ->(v) { v }},
    {field: "twitter", label: "X", icon: "x-twitter", hover: "hover:bg-black hover:fill-white border-base-200", url: ->(v) { "https://x.com/#{v}" }}
  ].freeze

  param :source
  option :variant, type: Dry::Types["coercible.symbol"].enum(:circle, :inline), default: proc { :circle }

  def platforms
    @platforms ||= PLATFORMS.filter_map do |config|
      field = config[:field]
      next unless source.respond_to?(field)

      value = source.public_send(field)
      next if value.blank?

      Platform.new(
        field: field,
        label: config[:label],
        icon: config[:icon],
        hover: config[:hover],
        url: config[:url].call(value)
      )
    end
  end

  def render?
    platforms.any?
  end

  private

  def inline?
    variant == :inline
  end
end
