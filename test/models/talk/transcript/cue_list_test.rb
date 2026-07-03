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

  private

  def cue(second)
    Talk::Transcript::Cue.new(
      start_time: Talk::Transcript::CueList.format_time(second * 1000),
      end_time: Talk::Transcript::CueList.format_time((second + 5) * 1000),
      text: "at #{second}"
    )
  end
end
