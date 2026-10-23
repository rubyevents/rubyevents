require "test_helper"

class TopicMatchJudgeTest < ActiveSupport::TestCase
  DECISIONS_URL = "https://api.openai.com/v1/decisions"

  setup do
    @topic = topics(:activerecord)
    @talk = talks(:one)
  end

  test "sends the topic as instructions and the talk as input" do
    stub_decisions(0.92)

    judgment = TopicMatchJudge.judge(TopicMatchJudge.input_for(@talk), topic: @topic)

    assert_in_delta 0.92, judgment.matches.probability
    assert_requested(:post, DECISIONS_URL) do |request|
      body = JSON.parse(request.body)
      question = body["questions"].sole

      assert_equal "gpt-6-luna", body["model"]
      assert_equal "predicate", question["type"]
      assert_equal "matches", question["name"]
      assert_includes question["instructions"], %("topic":"ActiveRecord")
      assert_includes question["instructions"], "Yes: The topic is a primary subject"
      assert_includes body["input"], @talk.title
    end
  end

  test "Topic::Agents#find_talks with the judge assigns talks above the threshold" do
    @topic.agents.stub(:find_candidate_talks, Talk.where(id: [talks(:two).id, talks(:three).id])) do
      stub_request(:post, DECISIONS_URL)
        .with { |request| request.body.include?(talks(:two).title) }
        .to_return(**decisions_response(0.95))
      stub_request(:post, DECISIONS_URL)
        .with { |request| request.body.include?(talks(:three).title) }
        .to_return(**decisions_response(0.4))

      @topic.agents.find_talks(matcher: :judge)
    end

    assert_includes @topic.reload.talks, talks(:two)
    assert_not_includes @topic.talks, talks(:three)
  end

  private

  def stub_decisions(probability)
    stub_request(:post, DECISIONS_URL).to_return(**decisions_response(probability))
  end

  def decisions_response(probability)
    {
      status: 200,
      headers: {"Content-Type" => "application/json"},
      body: {
        model: "gpt-6-luna",
        answers: [{probability: probability}],
        usage: {input_tokens: 120, output_tokens: 1}
      }.to_json
    }
  end
end
