class Spotlight::TopicsController < ApplicationController
  include TypesenseSearch

  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_available?
      pagy, @topics = Topic.typesense_search_topics(search_query, per_page: LIMIT)
      @total_count = pagy.count
    else
      @topics = Topic.approved.canonical.with_talks.order(talks_count: :desc)
      @topics = @topics.where("name LIKE ?", "%#{search_query}%") if search_query.present?
      @total_count = @topics.count
      @topics = @topics.limit(LIMIT)
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
