class TalksAgent < ApplicationAgent
  generate_with :openai,
    model: "gpt-4.1"

  before_action :set_talk
  after_generation :update_summary, only: [:summarize]
  after_generation :update_topics, only: [:analyze_topics]
  after_generation :update_enhanced_transcript, only: [:enhance_transcript]

  def enhance_transcript
    prompt(output_schema: :enhanced_transcript)
  end

  def summarize
    prompt(output_schema: :summary)
  end

  def analyze_topics
    prompt(output_schema: :topics)
  end

  private

  def set_talk
    @talk = Talk.find(params[:id])
  end

  def update_summary
    raw_response = JSON.repair(response.dig("choices", 0, "message", "content"))
    summary = JSON.parse(raw_response).dig("summary")
    talk.update!(summary: summary)
  end

  def update_topics
    raw_response = JSON.repair(response.dig("choices", 0, "message", "content"))
    topics = begin
      JSON.parse(raw_response)["topics"]
    rescue
      []
    end

    talk.topics = Topic.create_from_list(topics)
    talk.save!

    talk
  end
end
