# frozen_string_literal: true

# Renamed events keep their previous slugs as aliases (`old_ids` in event.yml), so
# pages nested under /events/:event_slug redirect an old slug to the current one.
# Events merged into a series (`old_event_ids` in series.yml) redirect to the series.
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

    event = Event.find_by_slug_or_alias(slug) || Event.find_by_series_slug_or_alias(slug)

    if event.nil? && (series = EventSeries.find_by_slug_or_alias(slug))
      return redirect_to(series_path(series), status: :moved_permanently)
    end

    return if event.nil? || event.slug == slug

    route = request.path_parameters.merge(controller: "/#{request.path_parameters[:controller]}", event_slug: event.slug)

    redirect_to url_for(**route, params: request.query_parameters, only_path: true), status: :moved_permanently
  end
end
