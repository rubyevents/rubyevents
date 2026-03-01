# frozen_string_literal: true

# Controller for showing notes about a user on the profile
class Profiles::NotesController < ApplicationController
  include ProfileData

  def index
    unless @favorite_user&.persisted?
      redirect_to profile_path(@user), alert: "You can only take notes on your favorites."
    end
  end
end
