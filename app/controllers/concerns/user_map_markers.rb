# frozen_string_literal: true

module UserMapMarkers
  extend ActiveSupport::Concern

  private

  def user_map_markers(users = User.canonical.geocoded.preloaded)
    users
      .group_by(&:to_coordinates)
      .map do |(latitude, longitude), grouped_users|
        {
          latitude: latitude,
          longitude: longitude,
          users: grouped_users
            .sort_by { |u| [-u.talks_count, u.name.to_s] }
            .map { |user| user_marker_data(user) }
        }
      end
  end

  def user_marker_data(user)
    {
      name: user.name,
      url: Router.profile_path(user),
      avatar: user.avatar_url(size: 100),
      location: user.location.presence || user.city,
      talks_count: user.talks_count,
      speaker: user.talks_count > 0
    }
  end
end
