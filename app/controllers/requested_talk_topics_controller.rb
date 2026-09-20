class RequestedTalkTopicsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!, only: %i[new create]

  def index
    scope = RequestedTalkTopic
      .includes(:user, :requested_talk_topic_votes)
      .search(params[:query])
      .with_status(params[:status])
      .sorted(params[:sort])

    @pagy, @requested_talk_topics = pagy(scope, limit: 20)
  end

  def show
    @requested_talk_topic = RequestedTalkTopic.find(params[:id])
  end

  def new
    @requested_talk_topic = RequestedTalkTopic.new
  end

  def create
    @requested_talk_topic = Current.user.requested_talk_topics.new(requested_talk_topic_params)

    if @requested_talk_topic.save
      redirect_to @requested_talk_topic, notice: "Your talk idea has been submitted."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def requested_talk_topic_params
    params.require(:requested_talk_topic).permit(:title, :description)
  end
end
