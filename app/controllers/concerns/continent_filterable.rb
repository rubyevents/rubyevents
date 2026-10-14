# frozen_string_literal: true

module ContinentFilterable
  extend ActiveSupport::Concern

  included do
    helper_method :selected_continent
  end

  private

  def selected_continent
    return @selected_continent if defined?(@selected_continent)

    @selected_continent = Continent.find(params[:continent])
  end

  def filter_by_continent(scope)
    return scope if selected_continent.nil?

    scope.where(country_code: selected_continent.country_codes)
  end
end
