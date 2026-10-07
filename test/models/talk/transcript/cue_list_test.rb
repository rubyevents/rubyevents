# frozen_string_literal: true

require "test_helper"

class Talk::Transcript::CueListTest < ActiveSupport::TestCase
  test "slice keeps only cues that start within the range (inclusive)" do
    cue_list = Talk::Transcript::CueList.new(cues: [cue(30), cue(90), cue(150), cue(210)])

    assert_equal ["at 90", "at 150"], cue_list.slice(60, 180).cues.map(&:text)
  end

  test "slice returns an empty cue list when nothing is in range" do
    sliced = Talk::Transcript::CueList.new(cues: [cue(30)]).slice(500, 600)

    assert_empty sliced.cues
    assert_nil sliced.presence
  end

  test "format_time renders milliseconds as HH:MM:SS.mmm" do
    {
      0 => "00:00:00.000",
      5 => "00:00:00.005",
      1_500 => "00:00:01.500",
      61_000 => "00:01:01.000",
      3_600_000 => "01:00:00.000",
      3_661_500 => "01:01:01.500",
      90_061_000 => "25:01:01.000"
    }.each do |ms, expected|
      assert_equal expected, Talk::Transcript::CueList.format_time(ms), "for #{ms}ms"
    end
  end

  test "passages groups cues into windowed chunks with start/end timestamps" do
    cue_list = Talk::Transcript::CueList.new(cues: [cue(0), cue(20), cue(40), cue(100), cue(120)])

    passages = cue_list.passages(window: 45)

    assert_equal 2, passages.size
    assert_equal 0, passages.first.start_seconds
    assert_equal 45, passages.first.end_seconds
    assert_equal "at 0 at 20 at 40", passages.first.text
    assert_equal 100, passages.last.start_seconds
    assert_equal "at 100 at 120", passages.last.text
  end

  test "deduplicated collapses rolling-caption repeats and tiny duplicate cues" do
    cues = [
      cue_with(0, "so there's been a"),
      cue_with(1, "so there's been a"),               # tiny exact-duplicate boundary cue
      cue_with(1, "so there's been a whole thing"),   # rolling: repeats previous tail + new words
      cue_with(2, "whole thing"),                     # tiny duplicate of the tail
      cue_with(2, "whole thing about rails")          # rolling
    ]

    result = Talk::Transcript::CueList.new(cues: cues).deduplicated.cues

    assert_equal ["so there's been a", "whole thing", "about rails"], result.map(&:text)
  end

  private

  def cue_with(second, text)
    Talk::Transcript::Cue.new(
      start_time: Talk::Transcript::CueList.format_time(second * 1000),
      end_time: Talk::Transcript::CueList.format_time((second + 1) * 1000),
      text: text
    )
  end

  def cue(second)
    Talk::Transcript::Cue.new(
      start_time: Talk::Transcript::CueList.format_time(second * 1000),
      end_time: Talk::Transcript::CueList.format_time((second + 5) * 1000),
      text: "at #{second}"
    )
  end
end
