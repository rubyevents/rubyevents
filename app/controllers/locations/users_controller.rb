# frozen_string_literal: true

class Locations::UsersController < Locations::BaseController
  def index
    @users = location_users

    if city?
      load_nearby_users
      load_state_users
    end

    render_location_view("users")
  end

  private

  def load_nearby_users
    return unless @city.geocoded?

    @nearby_users = @city.nearby_users(
      radius_km: 250,
      limit: 100,
      exclude_ids: @users.pluck(:id)
    )
  end

  def load_state_users
    return unless @state.present?

    city_user_ids = @users.pluck(:id)
    nearby_user_ids = (@nearby_users || []).map { |n| n.is_a?(Hash) ? n[:user].id : n.id }
    exclude_ids = city_user_ids + nearby_user_ids
    @state_users = @state.users.geocoded.where.not(id: exclude_ids).order(talks_count: :desc)
  end

  def redirect_path_helper
    :city_users_path
  end
end
