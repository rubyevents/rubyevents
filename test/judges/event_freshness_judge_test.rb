require "test_helper"

class EventFreshnessJudgeTest < ActiveSupport::TestCase
  DECISIONS_URL = "https://api.openai.com/v1/decisions"

  setup do
    @event = Static::Event.find_by_slug("balkanruby-2026")
  end

  test "judges the website text against the current event data" do
    stub_request(:get, "https://balkanruby.com/").to_return(status: 301, headers: {"Location" => "https://balkanruby.com/2026"})
    stub_request(:get, "https://balkanruby.com/2026").to_return(body: <<~HTML)
      <html><head><script>tracking()</script></head>
      <body><h1>Balkan Ruby 2026</h1><p>Sponsored by Acme Corp</p></body></html>
    HTML
    stub_decisions(edition: "this_edition", sponsors: 0.9)

    judgment = EventFreshnessJudge.check(@event)

    assert_equal :this_edition, judgment.edition.choice
    assert_equal [:sponsors], EventFreshnessJudge.stale_areas(judgment)
    assert_requested(:post, DECISIONS_URL) do |request|
      body = JSON.parse(request.body)
      input = JSON.parse(body["input"])

      assert_equal %w[edition] + EventFreshnessJudge::AREAS.map(&:to_s), body["questions"].pluck("name")
      assert_equal "Balkan Ruby 2026 Sponsored by Acme Corp", input.dig("website", "https://balkanruby.com")
      assert_equal "2026-05-15", input.dig("current_data", "event", "start_date")
      assert_includes input.dig("current_data", "sponsors", "Sponsors"), "Dext"
      assert_not_includes body["input"], "tracking()"
    end
  end

  test "reports unreachable websites to the model instead of raising" do
    stub_request(:get, "https://balkanruby.com/").to_raise(SocketError)
    stub_decisions(edition: "unrelated")

    judgment = EventFreshnessJudge.check(@event)

    assert_requested(:post, DECISIONS_URL) { |request| request.body.include?("Unreachable: SocketError") }
    assert_empty EventFreshnessJudge.stale_areas(judgment)
  end

  test "ignores area answers when the website moved on to another edition" do
    stub_request(:get, "https://balkanruby.com/").to_return(body: "<h1>Balkan Ruby 2027</h1>")
    stub_decisions(edition: "later_edition", dates: 0.99, talks: 0.95)

    assert_empty EventFreshnessJudge.stale_areas(EventFreshnessJudge.check(@event))
  end

  private

  def stub_decisions(edition:, **probabilities)
    answers = [{
      choice: edition,
      probabilities: [{value: edition, probability: 0.9}],
      confidence: 0.8
    }]
    answers += EventFreshnessJudge::AREAS.map { {probability: probabilities.fetch(it, 0.05)} }

    stub_request(:post, DECISIONS_URL).to_return(
      status: 200,
      headers: {"Content-Type" => "application/json"},
      body: {model: "gpt-6-luna", answers: answers, usage: {input_tokens: 4000, output_tokens: 11}}.to_json
    )
  end
end
