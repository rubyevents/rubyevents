class Events::ParticipantsController < ApplicationController
  include EventData

  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event
  before_action :set_event_meta_tags
  before_action :set_favorite_users, only: %i[index]
  before_action :set_participation, only: %i[index]
  before_action :set_participants, only: %i[index]

  def index
  end
end
