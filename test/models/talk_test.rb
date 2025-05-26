require "test_helper"

class TalkTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  test "should handle empty transcript" do
    talk = Talk.new(title: "Sample Talk", date: Date.today, talk_transcript_attributes: {raw_transcript: Transcript.new})
    assert talk.save

    loaded_talk = Talk.find(talk.id)
    assert_equal loaded_talk.transcript.cues, []
    assert_equal "Sample Talk", loaded_talk.title
  end

  test "should update transcript" do
    @talk = talks(:one)

    VCR.use_cassette("youtube/transcript") do
      perform_enqueued_jobs do
        @talk.fetch_and_update_raw_transcript!
      end
    end

    assert @talk.transcript.is_a?(Transcript)
    assert @talk.transcript.cues.first.is_a?(Cue)
    assert @talk.transcript.cues.length > 100
  end

  test "when the talk doesn't have any transcript yet" do
    @talk = Talk.create!(title: "Express Your Ideas by Writing Your Own Gems", video_id: "Md90cwnmGc8", video_provider: "youtube", date: Date.today)

    VCR.use_cassette("youtube/transcript_not_available") do
      perform_enqueued_jobs do
        @talk.fetch_and_update_raw_transcript!
      end
    end

    assert @talk.reload.transcript.is_a?(Transcript)
    assert @talk.transcript.cues.first.is_a?(Cue)
    assert @talk.transcript.cues.length > 100
  end

  test "should guess kind from title" do
    kind_with_titles = {
      talk: ["I love Ruby", "Beyond Code: Crafting effective discussions to further technical decision-making", "From LALR to IELR: A Lrama's Next Step"],
      keynote: ["Keynote: Something ", "Opening keynote Something", "closing keynote Something", "Keynote", "Keynote by Someone", "Opening Keynote", "Closing Keynote"],
      lightning_talk: ["Lightning Talk: Something", "lightning talk: Something", "Lightning talk: Something", "lightning talk", "Lightning Talks", "Lightning talks", "lightning talks", "Lightning Talks Day 1", "Lightning Talks (Day 1)", "Lightning Talks - Day 1", "Micro Talk: Something", "micro talk: Something", "micro talk: Something", "micro talk"],
      panel: ["Panel: foo", "Panel", "Something Panel"],
      workshop: ["Workshop: Something", "workshop: Something"],
      gameshow: ["Gameshow", "Game Show", "Gameshow: Something", "Game Show: Something"],
      podcast: ["Podcast: Something", "Podcast Recording: Something", "Live Podcast: Something"],
      q_and_a: ["Q&A", "Q&A: Something", "Something AMA", "Q&A with Somebody", "Ruby Committers vs The World", "Ruby Committers and the World", "AMA: Rails Core"],
      discussion: ["Discussion: Something", "Discussion", "Fishbowl: Topic", "Fishbowl Discussion: Topic"],
      fireside_chat: ["Fireside Chat: Something", "Fireside Chat"],
      interview: ["Interview with Matz", "Interview: Something"],
      award: ["Award: Something", "Award Show", "Ruby Heroes Awards", "Ruby Heroes Award", "Rails Luminary"]
    }

    kind_with_titles.each do |kind, titles|
      titles.each do |title|
        talk = Talk.new(title:, date: Date.today)
        talk.save!

        assert_equal [kind.to_s, title], [talk.kind, talk.title]

        talk.destroy!
      end
    end
  end

  test "should not guess a kind if it's provided" do
    talk = Talk.create!(title: "foo", kind: "panel", date: Date.today)

    assert_equal "panel", talk.kind
  end

  test "should not guess a kind if it's provided in the static metadata" do
    talk = Talk.create!(
      title: "Who Wants to be a Ruby Engineer?",
      video_provider: "mp4",
      video_id: "https://videos.brightonruby.com/videos/2024/drew-bragg-who-wants-to-be-a-ruby-engineer.mp4",
      date: Date.today
    )

    assert_equal "gameshow", talk.kind
  end

  test "transcript should default to raw_transcript" do
    raw_transcript = Transcript.new(cues: [Cue.new(start_time: 0, end_time: 1, text: "Hello")])
    talk = Talk.new(title: "Sample Talk", date: Date.today, talk_transcript_attributes: {raw_transcript: raw_transcript})
    assert talk.save

    loaded_talk = Talk.find(talk.id)
    assert_equal loaded_talk.transcript.cues.first.text, "Hello"
  end

  test "talks one has a valid transcript" do
    talk = talks(:one)
    assert talk.transcript.is_a?(Transcript)
    assert talk.transcript.cues.first.is_a?(Cue)
  end

  test "enhance talk transcript" do
    @talk = talks(:one)
    @talk = Talk.includes(event: :organisation).find(@talk.id)

    refute @talk.enhanced_transcript.cues.present?
    VCR.use_cassette("talks/transcript-enhancement") do
      assert_changes "@talk.reload.updated_at" do
        assert_changes "@talk.reload.enhanced_transcript.cues.count" do
          perform_enqueued_jobs do
            @talk.agents.improve_transcript_later
          end
        end
      end
      assert @talk.enhanced_transcript.cues.present?
    end
  end

  test "summarize talk" do
    @talk = talks(:one)
    @talk = Talk.includes(event: :organisation).find(@talk.id)

    refute @talk.summary.present?
    VCR.use_cassette("talks/summarize") do
      assert_changes "@talk.reload.summary.present?" do
        perform_enqueued_jobs do
          @talk.agents.summarize_later
        end
      end
      assert @talk.summary.present?
    end
  end

  test "extract topics" do
    @talk = talks(:one)

    VCR.use_cassette("talks/extract_topics") do
      assert_changes "@talk.topics.count" do
        perform_enqueued_jobs do
          @talk.agents.analyze_topics_later
        end
      end
    end
  end

  test "does not create duplicate topics" do
    @talk = talks(:one)

    perform_enqueued_jobs do
      VCR.use_cassette("talks/extract_topics", allow_playback_repeats: true) do
        @talk.agents.analyze_topics_later
        assert_no_changes "@talk.topics.count" do
          @talk.agents.analyze_topics_later
        end
      end
    end
  end

  test "update_from_yml_metadata" do
    @talk = talks(:one)
    @event = events(:rails_world_2023)
    @talk.update!(title: "New title", description: "New description", event: @event)

    assert_equal "New title", @talk.title
    assert_equal "New description", @talk.description

    @talk.update_from_yml_metadata!

    assert_equal "Hotwire Cookbook: Common Uses, Essential Patterns & Best Practices", @talk.title
  end

  test "language is english by default" do
    assert_equal "en", Talk.new.language
  end

  test "language is normalized to alpha2 code" do
    assert_equal "en", Talk.new(language: "English").language
    assert_equal "en", Talk.new(language: "english").language
    assert_equal "en", Talk.new(language: "en").language

    assert_equal "ja", Talk.new(language: "Japanese").language
    assert_equal "ja", Talk.new(language: "japanese").language
    assert_equal "ja", Talk.new(language: "ja").language

    assert_nil Talk.new(language: "doesntexist").language
    assert_nil Talk.new(language: "random").language
  end

  test "language must be valid and present" do
    talk = talks(:one)
    talk.language = "random"
    talk.valid?

    assert_equal 2, talk.errors.size
    assert_equal ["Language can't be blank", "Language  is not a valid IS0-639 alpha2 code"],
      talk.errors.map(&:full_message)
  end

  test "create a new talk with a nil language" do
    talk = Talk.create!(title: "New title", language: nil, date: Date.today)
    assert_equal "en", talk.language
    assert talk.valid?
  end

  test "full text search on title" do
    @talk = talks(:one)
    assert_equal [@talk], Talk.ft_search("Hotwire Cookbook")
    assert_equal [@talk], Talk.ft_search("Hotwire Cookbook: Common Uses, Essential Patterns")
    assert_equal [@talk], Talk.ft_search('Hotwire"') # with an escaped quote

    @talk.index.destroy!
    @talk.reload.reindex # Need to reload or we get a FrozenError from trying to update attributes on the destroyed index record.
    assert_equal [@talk], Talk.ft_search("Hotwire Cookbook")
  end

  test "full text search creating and deleting a talk" do
    talk = Talk.create!(title: "Full text seach with Sqlite", summary: "On using sqlite full text search with an ActiveRecord backed virtual table", date: Time.current)
    talk.speakers.create!(name: "Kasper Timm Hansen")

    assert_equal [talk], Talk.ft_search("sqlite full text search") # title
    assert_equal [talk], Talk.ft_search("ActiveRecord backed virtual table") # summary
    assert_equal [talk], Talk.ft_search("Kasper Timm Hansen") # speaker

    talk.destroy
    assert_empty Talk.ft_search("sqlite full text search")
    assert_empty Talk.ft_search("ActiveRecord backed virtual table")
    assert_empty Talk.ft_search("Kasper Timm Hansen")
  end

  test "full text search on title with snippets" do
    @talk = talks(:one)
    assert_equal [@talk], Talk.ft_search("Hotwire Cookbook").with_snippets
    first_result = Talk.ft_search("Hotwire Cookbook").with_snippets.first
    assert_equal "<mark>Hotwire</mark> <mark>Cookbook</mark>: Common Uses, Essential Patterns & Best Practices",
      first_result.title_snippet
  end

  test "full text search on summary" do
    @talk = talks(:one)
    @talk.update! summary: <<~HEREDOC
      Do ad cupidatat aliqua magna incididunt Lorem cillum velit voluptate duis dolore magna.
      Veniam aute labore non excepteur id pariatur ut exercitation labore.
      Dolor eu amet cupidatat dolore nisi nostrud elit tempor officia.
      Cupidatat exercitation voluptate esse officia tempor anim tempor adipisicing adipisicing commodo sint.
      In ea adipisicing dolore esse dolor velit nulla enim mollit est velit laboris laborum.
      Dolor ea non voluptate et et excepteur laborum tempor.
    HEREDOC

    assert_equal [@talk], Talk.ft_search("incididunt")
    assert_equal [@talk], Talk.ft_search("incid*")
  end

  test "full text search on summary with snippets" do
    @talk = talks(:one)
    @talk.update! summary: <<~HEREDOC
      Do ad cupidatat aliqua magna incididunt Lorem cillum velit voluptate duis dolore magna.
      Veniam aute labore non excepteur id pariatur ut exercitation labore.
      Dolor eu amet cupidatat dolore nisi nostrud elit tempor officia.
      Cupidatat exercitation voluptate esse officia tempor anim tempor adipisicing adipisicing commodo sint.
      In ea adipisicing dolore esse dolor velit nulla enim mollit est velit laboris laborum.
      Dolor ea non voluptate et et excepteur laborum tempor.
    HEREDOC

    assert_equal [@talk], Talk.ft_search("incididunt").with_snippets
    first_result = Talk.ft_search("incididunt").with_snippets.first
    assert_match "<mark>incididunt</mark>", first_result.summary_snippet
  end

  test "mark talk as watched" do
    talk = talks(:two)
    Current.user = users(:one)

    assert_equal 0, talk.watched_talks.count

    talk.mark_as_watched!

    assert_equal 1, talk.watched_talks.count
    assert talk.watched?
  end

  test "unmark talk as watched" do
    watched_talk = watched_talks(:one)
    talk = watched_talk.talk
    Current.user = users(:one)

    talk.unmark_as_watched!

    assert_equal 0, talk.watched_talks.count
    assert_not talk.watched?
  end

  test "should return a valid youtube thumbnail url" do
    talk = talks(:one)

    assert_match %r{^https://i.ytimg.com/vi/.*/sddefault.jpg$}, talk.thumbnail
  end

  test "should return a specific size youtube thumbnail url" do
    talk = talks(:one)

    assert_match %r{^https://i.ytimg.com/vi/.*/maxresdefault.jpg$}, talk.thumbnail(:thumbnail_xl)
  end

  test "should return the event thumbnail for non youtube talks" do
    talk = talks(:brightonruby_2024_one).tap do |t|
      ActiveRecord::Associations::Preloader.new(records: [t], associations: [event: :organisation]).call
    end

    assert_match %r{^/assets/events/brightonruby/brightonruby-2024/poster-.*.webp$}, talk.thumbnail
    assert_match %r{^/assets/events/brightonruby/brightonruby-2024/poster-.*.webp$}, talk.thumbnail(:thumbnail_xl)
  end

  test "for_topic" do
    talk = talks(:one)
    assert_includes Talk.for_topic("activerecord"), talk
  end

  test "discarded speaker_talks" do
    talk = talks(:one)
    speaker_talk = talk.speaker_talks.first
    assert_equal 1, speaker_talk.speaker.talks_count
    speaker_talk.discard
    assert_equal 1, talk.speaker_talks.count
    assert_equal 0, talk.kept_speaker_talks.count
    assert_equal 0, speaker_talk.speaker.talks_count
  end

  test "should return original title" do
    talk = talks(:non_english_talk_one)

    assert_equal "Palestra não em inglês", talk.original_title
  end
  test "llm request caching for transcript enhancement" do
    @talk = talks(:one)
    @talk = Talk.includes(event: :organisation).find(@talk.id)

    refute @talk.enhanced_transcript.cues.present?
    VCR.use_cassette("talks/transcript-enhancement") do
      assert_changes "@talk.reload.updated_at" do
        assert_changes "@talk.reload.enhanced_transcript.cues.count" do
          perform_enqueued_jobs do
            @talk.agents.improve_transcript_later
          end
        end
      end
      assert @talk.enhanced_transcript.cues.present?

      # Verify LLM request was created
      assert_equal 1, LLM::Request.count
      request = LLM::Request.first
      assert_equal @talk, request.resource
      assert request.duration > 0
      assert request.raw_response.present?

      # Second call should use cache
      assert_no_changes "LLM::Request.count" do
        perform_enqueued_jobs do
          @talk.agents.improve_transcript_later
        end
      end
    end
  end

  test "llm request caching for summarization" do
    @talk = talks(:one)
    @talk = Talk.includes(event: :organisation).find(@talk.id)

    refute @talk.summary.present?
    VCR.use_cassette("talks/summarize") do
      assert_changes "@talk.reload.summary.present?" do
        perform_enqueued_jobs do
          @talk.agents.summarize_later
        end
      end
      assert @talk.summary.present?

      # Verify LLM request was created
      assert_equal 1, LLM::Request.count
      request = LLM::Request.first
      assert_equal @talk, request.resource
      assert request.duration > 0
      assert request.raw_response.present?

      # Second call should use cache
      assert_no_changes "LLM::Request.count" do
        perform_enqueued_jobs do
          @talk.agents.summarize_later
        end
      end
    end
  end

  test "llm request caching for topic analysis" do
    @talk = talks(:one)

    VCR.use_cassette("talks/extract_topics") do
      assert_changes "@talk.topics.count" do
        perform_enqueued_jobs do
          @talk.agents.analyze_topics_later
        end
      end

      # Verify LLM request was created
      assert_equal 1, LLM::Request.count
      request = LLM::Request.first
      assert_equal @talk, request.resource
      assert request.duration > 0
      assert request.raw_response.present?

      # Second call should use cache
      assert_no_changes "LLM::Request.count" do
        perform_enqueued_jobs do
          @talk.agents.analyze_topics_later
        end
      end
    end
  end

  test "llm request caching with successful response" do
    @talk = talks(:one)
    @talk = Talk.includes(event: :organisation).find(@talk.id)

    VCR.use_cassette("talks/transcript-enhancement") do
      # First call should succeed and create a successful request
      assert_changes "@talk.reload.enhanced_transcript.cues.count" do
        perform_enqueued_jobs do
          @talk.agents.improve_transcript_later
        end
      end

      # Verify successful request was created
      assert_equal 1, LLM::Request.count
      request = LLM::Request.first
      assert_equal @talk, request.resource
      assert request.duration > 0
      assert request.raw_response.present?
      assert request.success

      # Second call should use cache
      assert_no_changes "LLM::Request.count" do
        perform_enqueued_jobs do
          @talk.agents.improve_transcript_later
        end
      end
    end
  end
end
