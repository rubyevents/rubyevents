class FavoriteUsersController < ApplicationController
  before_action :set_favorite_user, only: %i[destroy]

  # GET /favorite_users or /favorite_users.json
  def index
    @ruby_friends = FavoriteUser.where(user: Current.user).includes(:favorite_user, :mutual_favorite_user).where.associated(:mutual_favorite_user).order(favorite_user: {name: :asc})
    @favorite_rubyists = FavoriteUser.where(user: Current.user).includes(:favorite_user, :mutual_favorite_user).where.missing(:mutual_favorite_user).order(favorite_user: {name: :asc})
    @recommendations = FavoriteUser.recommendations_for(Current.user) if @favorite_rubyists.empty? && @ruby_friends.empty?
  end

  # POST /favorite_users or /favorite_users.json
  def create
    @favorite_user = FavoriteUser.new(favorite_user_params)
    @favorite_user.user = Current.user

    respond_to do |format|
      if @favorite_user.save
        format.html { redirect_back_or_to favorite_users_path, notice: "You favorited #{@favorite_user.favorite_user.name}!" }
      else
        format.html { redirect_back_or_to favorite_users_path, notice: "Favorite was unsuccessful." }
      end
    end
  end

  # DELETE /favorite_users/1 or /favorite_users/1.json
  def destroy
    @favorite_user.destroy!

    respond_to do |format|
      format.html { redirect_back_or_to favorite_users_path, status: :see_other }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_favorite_user
    @favorite_user = FavoriteUser.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def favorite_user_params
    params.expect(favorite_user: [:favorite_user_id])
  end
end
