class RequestedTalkTopicVotesController < ApplicationController
  before_action :authenticate_user!

  def create
    topic = RequestedTalkTopic.find(params[:requested_talk_topic_id])

    vote = topic.requested_talk_topic_votes.find_or_initialize_by(user: Current.user)

    vote.persisted? ? vote.destroy : vote.save!

    redirect_back fallback_location: requested_talk_topics_path
  end
end
