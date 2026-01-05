class Spotlight::TopicsController < ApplicationController
  include SpotlightSearch

  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present?
      @topics, @total_count = search_backend_class.search_topics(search_query, limit: LIMIT)
    else
      @topics = Topic.approved.canonical.with_talks.order(talks_count: :desc).limit(LIMIT)
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
