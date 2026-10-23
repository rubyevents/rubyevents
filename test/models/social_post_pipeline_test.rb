require "test_helper"

class SocialPostPipelineTest < ActiveSupport::TestCase
  DECISIONS_URL = "https://api.openai.com/v1/decisions"

  POST = {
    text: "Thanks to our new sponsor Acme Corp for supporting Balkan Ruby 2026!",
    platform: "bluesky",
    author: "balkanruby.com",
    links: ["https://balkanruby.com"]
  }.freeze

  test "stops after the relevance stage for irrelevant posts" do
    stub_decisions(relevance(0.1))

    result = SocialPostPipeline.call(**POST)

    assert_equal :irrelevant, result.outcome
    assert_requested :post, DECISIONS_URL, times: 1
  end

  test "stops when no series in the dataset matches the post" do
    stub_decisions(relevance(0.95))

    result = SocialPostPipeline.call(text: "Announcing Unheard Of Conf 2027!", platform: "x", author: "@unheardof")

    assert_equal :unknown_series, result.outcome
    assert_empty result.candidates
    assert_requested :post, DECISIONS_URL, times: 1
  end

  test "matches the event and flags the areas that need updating" do
    stub_decisions(relevance(0.95), match("balkanruby-2026"), comparison(needs_update: 0.9, sponsors: 0.92))

    result = SocialPostPipeline.call(**POST)

    assert_equal :needs_update, result.outcome
    assert_equal "balkanruby-2026", result.event.id
    assert_equal [:sponsors], result.update_areas
    assert_requested :post, DECISIONS_URL, times: 3
    assert_requested(:post, DECISIONS_URL) do |request|
      choices = JSON.parse(request.body)["questions"].first["choices"]
      choices&.pluck("value")&.include?("balkanruby-2026") && choices.pluck("value").include?(EventMatchJudge::NEW_EVENT)
    end
  end

  test "reports posts that are already reflected in the dataset" do
    stub_decisions(relevance(0.95), match("balkanruby-2026"), comparison(already_present: 0.9, needs_update: 0.1))

    assert_equal :up_to_date, SocialPostPipeline.call(**POST).outcome
  end

  test "flags posts about events missing from the dataset" do
    stub_decisions(relevance(0.95), match(EventMatchJudge::NEW_EVENT))

    result = SocialPostPipeline.call(**POST)

    assert_equal :new_event, result.outcome
    assert_nil result.event
  end

  test "does not trust low-confidence matches" do
    stub_decisions(relevance(0.95), match("balkanruby-2026", probability: 0.4))

    assert_equal :uncertain_match, SocialPostPipeline.call(**POST).outcome
  end

  private

  def stub_decisions(*answer_sets)
    responses = answer_sets.map do |answers|
      {
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {model: "gpt-6-luna", answers: answers, usage: {input_tokens: 500, output_tokens: 10}}.to_json
      }
    end

    stub_request(:post, DECISIONS_URL).to_return(*responses)
  end

  def relevance(probability)
    [{probability: probability}, choice("conference")] + SocialPostJudge::AREAS.map { {probability: 0.05} }
  end

  def match(event, probability: 0.9)
    [choice(event, probability:)]
  end

  def comparison(already_present: 0.1, needs_update: 0.1, **areas)
    [{probability: already_present}, {probability: needs_update}] + PostDataJudge::AREAS.map { {probability: areas.fetch(it, 0.05)} }
  end

  def choice(value, probability: 0.9)
    {choice: value, probabilities: [{value: value, probability: probability}], confidence: probability}
  end
end
