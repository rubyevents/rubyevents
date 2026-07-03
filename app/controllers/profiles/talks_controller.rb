class Profiles::TalksController < ApplicationController
  include ProfileData

  def index
    @talks = @user.kept_talks.includes(:speakers, event: :series, child_talks: :speakers).order(date: :desc)
    @talks_by_kind = @talks.group_by(&:kind)
  end
end
