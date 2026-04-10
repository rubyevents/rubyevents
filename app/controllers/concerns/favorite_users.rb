module FavoriteUsers
  extend ActiveSupport::Concern

  def set_favorite_users
    @favorite_users = {}
    return unless Current.user
    @favorite_users = Current.user.favorite_users
      .includes(:mutual_favorite_user)
      .to_h { [it.favorite_user_id, it] }
    @favorite_users.default_proc = proc { |hash, key| FavoriteUser.new(user: Current.user, favorite_user_id: key) }
  end
end
