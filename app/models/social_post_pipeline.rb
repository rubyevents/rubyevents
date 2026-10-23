# Triages a social media post in three judged stages, stopping as soon as one
# rules the post out:
#
# 1. SocialPostJudge: is the post relevant to the data we collect?
# 2. EventMatchJudge: which event in the dataset is it about? Candidates come
#    from series whose name, aliases, handles, or websites appear in the post.
# 3. PostDataJudge: is it already in our data, or does the data need updating?
#
#   result = SocialPostPipeline.call(text: "...", platform: "bluesky", author: "balkanruby.com", links: [...])
#   result.outcome      # => :needs_update
#   result.event        # => #<Static::Event balkanruby-2026>
#   result.update_areas # => [:sponsors]
#
class SocialPostPipeline
  RELEVANCE_THRESHOLD = 0.7
  MATCH_THRESHOLD = 0.6
  UPDATE_THRESHOLD = 0.7
  CANDIDATE_WINDOW = 18.months
  MAX_CANDIDATES = 15

  Result = Data.define(:outcome, :post, :relevance, :candidates, :match, :event, :comparison) do
    def needs_update? = outcome == :needs_update

    def update_areas = comparison ? PostDataJudge.update_areas(comparison) : []
  end

  def self.call(**post)
    new(**post).call
  end

  attr_reader :post

  def initialize(text:, platform:, author:, posted_at: nil, links: [])
    @post = SocialPostJudge.input_for(text:, platform:, author:, posted_at:, links:)
    @links = links
  end

  def call
    RubyLLM.workflow("Social post triage") { |workflow| run(workflow) }
  end

  def candidate_events
    events = candidate_series.flat_map { it.events.to_a }
    recent = events.select { |event| event_date(event).nil? || event_date(event) >= CANDIDATE_WINDOW.ago.to_date }

    recent.sort_by { event_date(it) || Date.new(9999) }.first(MAX_CANDIDATES)
  end

  private

  def run(workflow)
    relevance = workflow.step("Relevance") { SocialPostJudge.judge(post) }
    return result(:irrelevant, relevance:) if relevance.relevant.probability < RELEVANCE_THRESHOLD

    candidates = workflow.step("Candidates") { candidate_events }
    return result(:unknown_series, relevance:, candidates:) if candidates.empty?

    match = workflow.step("Match") { EventMatchJudge.judge(post, candidates:) }
    choice = match.event.choice
    return result(:uncertain_match, relevance:, candidates:, match:) if match.event.probabilities[choice] < MATCH_THRESHOLD
    return result(:new_event, relevance:, candidates:, match:) if choice == EventMatchJudge::NEW_EVENT
    return result(:no_event, relevance:, candidates:, match:) if choice == EventMatchJudge::NO_EVENT

    event = candidates.find { it.id == choice }
    comparison = workflow.step("Compare") { PostDataJudge.judge(PostDataJudge.input_for(post, event)) }
    outcome = (comparison.needs_update.probability >= UPDATE_THRESHOLD) ? :needs_update : :up_to_date

    result(outcome, relevance:, candidates:, match:, event:, comparison:)
  end

  def result(outcome, relevance:, candidates: [], match: nil, event: nil, comparison: nil)
    Result.new(outcome:, post:, relevance:, candidates:, match:, event:, comparison:)
  end

  def candidate_series
    text = post[:text].downcase
    hosts = @links.filter_map { host(it) }
    linked_series_ids = hosts.any? ? Static::Event.all.select { hosts.include?(host(it.website)) }.map(&:series_id) : []

    Static::EventSeries.all.select do |series|
      attributes = series.to_h
      names = [attributes["name"], *attributes["aliases"]].compact

      names.any? { text.match?(/(?<![[:alnum:]])#{Regexp.escape(it.downcase)}(?![[:alnum:]])/) } ||
        hosts.include?(host(attributes["website"])) ||
        linked_series_ids.include?(series.id) ||
        handles(attributes).include?(normalize_handle(post[:author]))
    end
  end

  def handles(attributes)
    mastodon = attributes["mastodon"]&.then { |url| URI(url).then { "#{it.path.delete_prefix("/")}@#{it.host}" } }

    [attributes["twitter"], attributes["bsky"], mastodon].compact.map { normalize_handle(it) }
  rescue URI::InvalidURIError
    []
  end

  def normalize_handle(handle)
    handle.to_s.downcase.delete_prefix("@")
  end

  def host(url)
    URI(url.to_s).host&.downcase&.delete_prefix("www.")
  rescue URI::InvalidURIError
    nil
  end

  def event_date(event)
    value = event.to_h["end_date"] || event.to_h["start_date"]
    Date.parse(value) if value.present?
  rescue Date::Error
    nil
  end
end
