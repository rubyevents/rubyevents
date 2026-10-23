require "test_helper"

class TalkTopicsJudgeTest < ActiveSupport::TestCase
  DECISIONS_URL = "https://api.openai.com/v1/decisions"
  Transcript = Data.define(:to_text)

  setup do
    @talk = talks(:one)
    @hotwire = Topic.create!(name: "Hotwire", status: :approved, description: "Turbo and Stimulus")
    @candidates = [topics(:activerecord), @hotwire, topics(:one)]
  end

  test "asks one score question per candidate topic" do
    stub_scores(activerecord: 0.4, hotwire: 3.0, "topic-1": 1.0)

    judgment = TalkTopicsJudge.judge_topics(@talk, @candidates)

    assert_in_delta 3.0, judgment.fetch("hotwire").score
    assert_requested(:post, DECISIONS_URL) do |request|
      body = JSON.parse(request.body)
      hotwire = body["questions"].find { it["name"] == "hotwire" }

      assert_equal %w[activerecord hotwire topic-1], body["questions"].pluck("name")
      assert_equal "score", hotwire["type"]
      assert_equal TalkTopicsJudge::LEVELS, hotwire["levels"].pluck("description")
      assert_includes hotwire["instructions"], "Turbo and Stimulus"
      assert_includes body["input"], @talk.title
    end
  end

  test "picks topics above the minimum score, best first, up to the limit" do
    stub_scores(activerecord: 2.4, hotwire: 3.0, "topic-1": 1.0)
    judgment = TalkTopicsJudge.judge_topics(@talk, @candidates)

    assert_equal [@hotwire, topics(:activerecord)], TalkTopicsJudge.pick(judgment, @candidates)
    assert_equal [@hotwire], TalkTopicsJudge.pick(judgment, @candidates, limit: 1)
  end

  test "Talk::Agents#analyze_topics_with_judge replaces the talk's topics with the picked ones" do
    stub_scores(activerecord: 0.5, hotwire: 2.9, "topic-1": 0.2)

    @talk.stub(:raw_transcript, "present") do
      @talk.stub(:transcript, Transcript.new("Today we build modals with Hotwire")) do
        Talk::TopicCandidates.stub(:for, @candidates) { @talk.agents.analyze_topics_with_judge }
      end
    end

    assert_equal [@hotwire], @talk.reload.topics.to_a
  end

  test "Talk::Agents#topic_scores ranks candidates without saving" do
    stub_scores(activerecord: 0.5, hotwire: 2.9, "topic-1": 1.2)

    scores = @talk.agents.topic_scores(@candidates)

    assert_equal [@hotwire, topics(:one), topics(:activerecord)], scores.keys
    assert_not_includes @talk.reload.topics, @hotwire
  end

  private

  def stub_scores(scores)
    answers = scores.values.map do |score|
      level = score.round.to_s
      {score: score, probabilities: [{label: level, probability: 0.8}], confidence: 0.7}
    end

    stub_request(:post, DECISIONS_URL).to_return(
      status: 200,
      headers: {"Content-Type" => "application/json"},
      body: {model: "gpt-6-luna", answers: answers, usage: {input_tokens: 9000, output_tokens: 3}}.to_json
    )
  end
end
