module Admin
  class SuggestionsController < ApplicationController
    include Pagy::Backend

    before_action :require_admin!

    def index
      @pagy, @suggestions = pagy(Suggestion.pending.order(created_at: :asc))
    end

    def update
      @suggestion = Suggestion.find(params[:id])
      @suggestion.approved!(approver: Current.user)
      redirect_to admin_suggestions_path
    end

    def destroy
      @suggestion = Suggestion.find(params[:id])
      @suggestion.rejected!
      redirect_to admin_suggestions_path
    end

    private

    def require_admin!
      redirect_to root_path, alert: "Not authorized" unless Current.user&.admin?
    end
  end
end
