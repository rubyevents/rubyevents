class Spotlight::TalksController < ApplicationController
  include TypesenseSearch

  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_available?
      pagy, @talks = Talk.typesense_search_talks(search_query, per_page: LIMIT)
      @total_count = pagy.count
    elsif search_query.present?
      @talks = Talk.watchable.includes(:speakers, event: :series)
      @talks = @talks.ft_search(search_query)
      @total_count = @talks.except(:select).count
      @talks = @talks.limit(LIMIT)
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
