# frozen_string_literal: true

class States::BaseController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :set_state

  private

  def set_state
    @country = Country.find_by(country_code: params[:state_alpha2].upcase)
    redirect_to(countries_path) and return unless @country.present?

    @state = State.find(country: @country, term: params[:state_slug])
    redirect_to(country_path(@country)) and return unless @state.present?
  end
end
