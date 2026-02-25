module Admin
  class SuggestionsController < ApplicationController
    include Pagy::Backend

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
  end
end
