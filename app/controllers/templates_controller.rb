class TemplatesController < ApplicationController
  skip_before_action :authenticate_user!

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

  private

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
