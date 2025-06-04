class Events::PastController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @events = Event.all.select { |event| event.end_date }.select { |event| event.end_date <= Date.today }.select { |event| event.organisation.conference? }.sort_by { |event| event.start_date }.reverse
  end
end
