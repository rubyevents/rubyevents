class Data::ChangesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :require_admin!

  def index
    @changes = Static::DataImporter.changes
  end

  private

  def require_admin!
    return if Rails.env.development?

    head :not_found unless Current.user&.admin?
  end
end
