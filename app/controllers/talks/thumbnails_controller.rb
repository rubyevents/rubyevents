class Talks::ThumbnailsController < ApplicationController
  skip_before_action :authenticate_user!, only: :show

  disable_analytics

  skip_before_action :track_ahoy_visit, only: :show, raise: false
  before_action :skip_session, only: :show
  after_action :force_public_caching, only: :show

  def show
    talk = Talk.find_by_slug_or_alias(params[:talk_slug])
    return head :not_found if talk.blank?

    variant = params[:variant].to_s
    png = Talk::ThumbnailGenerator.new(talk, variant: variant).cached_png

    if png.blank?
      talk.thumbnails.enqueue_generation(variant: variant)

      return serve_placeholder(talk)
    end

    etag = [talk.thumbnail_cache_version, variant, "thumbnail-v1"]

    if stale?(etag: etag, public: true)
      expires_in 1.year, public: true
      send_data png, type: "image/png", disposition: "inline"
    end
  end

  private

  def serve_placeholder(talk)
    response.headers["Cache-Control"] = "no-store"
    redirect_to talk.poster_thumbnail, allow_other_host: false
  end

  def skip_session
    request.session_options[:skip] = true
  end

  def force_public_caching
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable" if response.successful?
  end
end
