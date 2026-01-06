class FeaturedCitiesController < ApplicationController
  before_action :require_admin
  before_action :set_featured_city, only: [:destroy]

  def create
    @country = Country.find_by(country_code: params[:country_code]&.upcase)
    redirect_to cities_path, alert: "Invalid country code" and return if @country.blank?

    @state = params[:state_code].present? ? State.find(country: @country, term: params[:state_code]) : nil
    city_slug = params[:city_slug]
    city_name = city_slug.tr("-", " ").titleize

    city = City.new(
      name: city_name,
      slug: city_slug,
      country_code: @country.alpha2,
      state_code: @state&.code
    )

    featured_city = city.feature!
    redirect_to city_path(featured_city.slug), notice: "#{featured_city.name} has been featured!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: cities_path, alert: "Failed to feature city: #{e.message}"
  end

  def destroy
    city_name = @featured_city.name
    country_code = @featured_city.country_code
    state_code = @featured_city.state_code
    city_slug = @featured_city.slug

    @featured_city.destroy

    state = state_code.present? ? State.find_by_code(state_code, country: Country.find_by(country_code: country_code)) : nil
    redirect_path = if state.present?
      city_with_state_path(alpha2: country_code, state: state.slug, city: city_slug)
    else
      city_by_country_path(alpha2: country_code, city: city_slug)
    end

    redirect_to redirect_path, notice: "#{city_name} has been unfeatured."
  end

  private

  def set_featured_city
    @featured_city = FeaturedCity.find_by(slug: params[:slug])
    redirect_to cities_path, alert: "City not found" unless @featured_city
  end

  def require_admin
    unless Current.user&.admin?
      redirect_to cities_path, alert: "Admin access required"
    end
  end
end
