# frozen_string_literal: true

class Ui::SocialLinksComponent < ApplicationComponent
  Platform = Data.define(:field, :label, :icon, :url)

  LINK_CLASS = "inline-flex items-center justify-center size-6 box-content p-2 -m-2 text-gray-400 hover:text-gray-900 rounded focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary focus-visible:text-gray-900"

  PLATFORMS = [
    {field: "bsky", label: "Bluesky", icon: "bluesky", url: ->(v) { v.start_with?("http") ? v : "https://bsky.app/profile/#{v}" }},
    {field: "facebook", label: "Facebook", icon: "facebook", url: ->(v) { v.start_with?("http") ? v : "https://www.facebook.com/#{v}" }},
    {field: "github", label: "GitHub", icon: "github", url: ->(v) { v.start_with?("http") ? v : "https://github.com/#{v}" }},
    {field: "instagram", label: "Instagram", icon: "instagram", url: ->(v) { v.start_with?("http") ? v : "https://www.instagram.com/#{v}" }},
    {field: "linkedin", label: "LinkedIn", icon: "linkedin", url: ->(v) { v.start_with?("http") ? v : "https://www.linkedin.com/in/#{v}" }},
    {field: "mastodon", label: "Mastodon", icon: "mastodon", url: ->(v) { v.start_with?("http") ? v : "https://#{v}" }},
    {field: "meetup", label: "Meetup", icon: "meetup", url: ->(v) { v.start_with?("http") ? v : "https://www.meetup.com/#{v}" }},
    {field: "twitter", label: "X", icon: "x-twitter", url: ->(v) { v.start_with?("http") ? v : "https://x.com/#{v}" }}
  ].freeze

  param :source

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
        url: config[:url].call(value)
      )
    end
  end

  def render?
    platforms.any?
  end
end
