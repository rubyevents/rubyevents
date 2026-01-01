class WrappedController < ApplicationController
  skip_before_action :authenticate_user!
  layout "application"

  YEAR = 2025

  def index
    @year = YEAR

    @public_users = User
      .where(wrapped_public: true)
      .where.not("LOWER(users.name) IN (?)", ["tbd", "todo", "tba", "speaker tbd", "speaker tba"])
      .order(updated_at: :desc)
      .limit(100)
  end
end
