# frozen_string_literal: true

# The links of a meetup and of its group, the platforms people RSVP on, and the website.
#
module MeetupLinks
  HOSTS = {
    "meetup" => %w[meetup.com],
    "luma" => %w[luma.com lu.ma],
    "kommunity" => %w[kommunity.com]
  }.freeze

  PLATFORMS = HOSTS.keys.freeze
  FIELDS = [*PLATFORMS, "website"].freeze

  EVENT_URLS = {
    "meetup" => %r{https?://(?:www\.)?meetup\.com/[^\s<>")\]]+/events/\d+/?},
    "luma" => %r{https?://(?:www\.)?(?:lu\.ma|luma\.com)/[A-Za-z0-9_-]+},
    "kommunity" => %r{https?://(?:www\.)?kommunity\.com/[^\s<>")\]]+/events/[^\s<>")\]]+}
  }.freeze

  def self.field_for(url)
    host = URI.parse(url.to_s).host.to_s.delete_prefix("www.")

    HOSTS.find { |_field, hosts| hosts.any? { |domain| host == domain || host.end_with?(".#{domain}") } }&.first || "website"
  rescue URI::InvalidURIError
    "website"
  end
end
