class Spotlight::LanguagesController < ApplicationController
  include SpotlightSearch

  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present?
      @languages, @total_count = search_backend_class.search_languages(search_query, limit: LIMIT)
    else
      @languages = []
      @total_count = nil
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s].presence
  end

  helper_method :total_count
  attr_reader :total_count
end
