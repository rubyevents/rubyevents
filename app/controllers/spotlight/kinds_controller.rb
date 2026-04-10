class Spotlight::KindsController < ApplicationController
  include SpotlightSearch

  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present?
      @kinds, @total_count = search_backend.search_kinds(search_query, limit: LIMIT)
    else
      @kinds = []
      @total_count = 0
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def search_backend
    @search_backend ||= Search::Backend.resolve(params[:search_backend])
  end

  helper_method :search_query
  def search_query
    params[:s].presence
  end

  helper_method :total_count
  attr_reader :total_count
end
