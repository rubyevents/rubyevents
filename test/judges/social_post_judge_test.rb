require "test_helper"

class SocialPostJudgeTest < ActiveSupport::TestCase
  DECISIONS_URL = "https://api.openai.com/v1/decisions"

  test "sends the post and known events as input" do
    stub_decisions(relevant: 0.97, event_kind: "conference", cfp: 0.95, talks: 0.3)
    event = Static::Event.find_by_slug("balkanruby-2026")

    input = SocialPostJudge.input_for(
      text: "The Balkan Ruby 2027 CFP is open until January 31st!",
      platform: "bluesky",
      author: "balkanruby.com",
      posted_at: Time.utc(2026, 10, 1, 12),
      links: ["https://balkanruby.com/cfp"],
      known_events: [event]
    )
    judgment = SocialPostJudge.judge(input)

    assert_equal :conference, judgment.event_kind.choice
    assert_equal [:cfp], SocialPostJudge.relevant_areas(judgment)
    assert_requested(:post, DECISIONS_URL) do |request|
      body = JSON.parse(request.body)
      sent = JSON.parse(body["input"])

      assert_equal %w[relevant event_kind] + SocialPostJudge::AREAS.map(&:to_s), body["questions"].pluck("name")
      assert_equal "bluesky", sent["platform"]
      assert_equal "2026-10-01T12:00:00Z", sent["posted_at"]
      assert_equal "Balkan Ruby 2026", sent.dig("known_events", 0, "title")
    end
  end

  test "has no relevant areas when the post itself is irrelevant" do
    stub_decisions(relevant: 0.1, event_kind: "none", cfp: 0.8)

    judgment = SocialPostJudge.judge(SocialPostJudge.input_for(text: "Ruby is fun", platform: "mastodon", author: "@someone@ruby.social"))

    assert_empty SocialPostJudge.relevant_areas(judgment)
  end

  private

  def stub_decisions(relevant:, event_kind:, **probabilities)
    answers = [
      {probability: relevant},
      {
        choice: event_kind,
        probabilities: [{value: event_kind, probability: 0.9}],
        confidence: 0.8
      }
    ]
    answers += SocialPostJudge::AREAS.map { {probability: probabilities.fetch(it, 0.05)} }

    stub_request(:post, DECISIONS_URL).to_return(
      status: 200,
      headers: {"Content-Type" => "application/json"},
      body: {model: "gpt-6-luna", answers: answers, usage: {input_tokens: 300, output_tokens: 11}}.to_json
    )
  end
end
