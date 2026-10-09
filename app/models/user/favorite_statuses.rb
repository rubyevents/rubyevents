class User::FavoriteStatuses < ActiveRecord::AssociatedObject
  def map
    @map ||= kinds.transform_values { |kind| User::FavoriteStatus.new(kind) }
  end

  private

  def kinds
    Rails.cache.fetch(cache_key, expires_in: 1.day) do
      user.favorite_users.includes(:mutual_favorite_user).each_with_object({}) do |favorite, result|
        result[favorite.favorite_user_id] = favorite.ruby_friend? ? :ruby_friend : :favorite
      end
    end
  end

  def cache_key
    ["favorite_user_statuses", user.id, favorites_involving_user.cache_key_with_version]
  end

  def favorites_involving_user
    FavoriteUser.where(user_id: user.id).or(FavoriteUser.where(favorite_user_id: user.id))
  end
end
