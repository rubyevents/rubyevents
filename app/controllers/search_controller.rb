class SearchController < ApplicationController
  def index
    @result = params[:query]
    if @result.present?
      # return some search results here?
    end
  end
end