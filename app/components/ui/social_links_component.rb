# frozen_string_literal: true

class Ui::SocialLinksComponent < ApplicationComponent
  Platform = Data.define(:field, :label, :icon, :hover, :url)

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
    false
  end
end
