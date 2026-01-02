class Spotlight::TalksController < ApplicationController
  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_enabled?
      pagy, @talks = Talk.typesense_search_talks(search_query, per_page: LIMIT)
      @total_count = pagy.count
    else
      @talks = Talk.watchable.includes(:speakers, event: :series)
      @talks = @talks.ft_search(search_query) if search_query.present?
      @total_count = @talks.count
      @talks = @talks.limit(LIMIT)
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s]
  end

  helper_method :total_count
  attr_reader :total_count

  def typesense_enabled?
    Talk.respond_to?(:typesense_search_talks)
  end
end
