# frozen_string_literal: true

# Renamed events keep their previous slugs as aliases (`old_ids` in event.yml), so
# pages nested under /events/:event_slug redirect an old slug to the current one.
#
module EventSlugRedirect
  extend ActiveSupport::Concern

  included do
    prepend_before_action :redirect_renamed_event_slug, if: -> { params[:event_slug].present? && (request.get? || request.head?) }
  end

  private

  def redirect_renamed_event_slug
    slug = params[:event_slug].to_s
    return if Event.exists?(slug: slug)

    event = Event.find_by_slug_or_alias(slug)
    return if event.nil? || event.slug == slug

    path = request.path.sub(%r{/#{Regexp.escape(slug)}(?=/|\.|\z)}, "/#{event.slug}")

    redirect_to [path, request.query_string.presence].compact.join("?"), status: :moved_permanently
  end
end
