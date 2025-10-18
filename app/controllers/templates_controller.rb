class TemplatesController < ApplicationController
  include Turbo::ForceResponse

  skip_before_action :authenticate_user!
  force_frame_response only: [:new_child, :delete_child]
  force_stream_response only: [:speakers_search]

  def new
    @talk = Template.new
  end

  def create
    @talk = Template.new(talk_params)
    if @talk.valid?
      @yaml = @talk.to_yaml
      render :new
    else
      render :new, status: :unprocessable_entity
    end
  end

  def new_child
    @index = Time.now.to_i
  end

  def delete_child
  end

  def speakers_search
    @speakers = User.speakers.canonical
    @speakers = @speakers.ft_search(search_query) if search_query
    @speakers = @speakers.limit(100)
  end

  def speakers_search_chips
    @speakers = params[:combobox_values].split(",").map do |value|
      User.speakers.find_by(id: value) || OpenStruct.new(to_combobox_display: value, id: value)
    end
    render turbo_stream: helpers.combobox_selection_chips_for(@speakers)
  end

  private

  helper_method :search_query

  def search_query
    params[:q].presence
  end

  def talk_params
    params.require(:template).permit(
      :title, :raw_title, :description, :event_name, :date, :published_at, :announced_at,
      :video_provider, :video_id, :language, :track, :slides_url,
      :thumbnail_xs, :thumbnail_sm, :thumbnail_md, :thumbnail_lg,
      :external_player, :external_player_url, :start_cue, :end_cue,
      :speakers,
      children_attributes: [
        :title, :event_name, :date, :description, :video_id, :video_provider, :slides_url,
        :published_at, :speakers, :start_cue, :end_cue
      ]
    )
  end
end
