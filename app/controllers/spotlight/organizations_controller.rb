class Spotlight::OrganizationsController < ApplicationController
  include TypesenseSearch

  LIMIT = 8

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_available?
      pagy, @organizations = Organization.typesense_search_organizations(search_query, per_page: LIMIT)
      @total_count = pagy.count
    else
      @organizations = Organization.joins(:sponsors).distinct.order(name: :asc)
      @organizations = @organizations.where("organizations.name LIKE ?", "%#{search_query}%") if search_query.present?
      @total_count = @organizations.count
      @organizations = @organizations.limit(LIMIT)
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
