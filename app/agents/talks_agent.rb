class TalksAgent < ApplicationAgent
  generate_with :openai, 
    model: "gpt-4.1"

  before_action :set_talk
  after_generation

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
end
