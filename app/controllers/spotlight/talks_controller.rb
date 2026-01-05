class Spotlight::TalksController < ApplicationController
  include SpotlightSearch

  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present?
      @talks, @total_count = search_backend_class.search_talks(search_query, limit: LIMIT)
    else
      @talks = Talk.watchable.includes(:speakers, event: :series).order(date: :desc).limit(LIMIT)
      @total_count = nil
    end

    respond_to do |format|
      format.turbo_stream do
        response.headers["X-Search-Backend"] = search_backend.to_s if Rails.env.development? && search_backend
      end
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s]
  end

  helper_method :total_count
  attr_reader :total_count
end
