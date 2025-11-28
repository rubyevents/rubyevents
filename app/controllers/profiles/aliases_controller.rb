class Profiles::AliasesController < ApplicationController
  include ProfileData

  before_action :require_admin!

  def index
    @aliases = @user.aliases
  end

  private

  def require_admin!
    redirect_to profile_path(@user), alert: "Not authorized" unless Current.user&.admin?
  end
end
