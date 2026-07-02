# frozen_string_literal: true

require "test_helper"

class Talk::KindTest < ActiveSupport::TestCase
  KIND_WITH_TITLES = {
    talk: ["I love Ruby", "Beyond Code: Crafting effective discussions to further technical decision-making", "From LALR to IELR: A Lrama's Next Step", "Introduction to Ruby Fibers and the SchedulerInterface", "3D Printing, Ruby and Solar Panels"],
    keynote: ["Keynote: Something ", "Opening keynote Something", "closing keynote Something", "Keynote", "Keynote by Someone", "Opening Keynote", "Closing Keynote"],
    lightning_talk: ["Lightning Talk: Something", "lightning talk: Something", "Lightning talk: Something", "lightning talk", "Lightning Talks", "Lightning talks", "lightning talks", "Lightning Talks Day 1", "Lightning Talks (Day 1)", "Lightning Talks - Day 1", "Micro Talk: Something", "micro talk: Something", "micro talk: Something", "micro talk"],
    panel: ["Panel: foo", "Panel", "Something Panel"],
    workshop: ["Workshop: Something", "workshop: Something"],
    gameshow: ["Gameshow", "Game Show", "Gameshow: Something", "Game Show: Something"],
    podcast: ["Podcast: Something", "Podcast Recording: Something", "Live Podcast: Something"],
    q_and_a: ["Q&A", "Q&A: Something", "Something AMA", "Q&A with Somebody", "Ruby Committers vs The World", "Ruby Committers and the World", "AMA: Rails Core", "Questions and Answers", "Questions and Answers: Something", "Questions and Answers with Matz"],
    discussion: ["Discussion: Something", "Discussion", "Fishbowl: Topic", "Fishbowl Discussion: Topic"],
    fireside_chat: ["Fireside Chat: Something", "Fireside Chat"],
    interview: ["Interview with Matz", "Interview: Something"],
    award: ["Award: Something", "Award Show", "Ruby Heroes Awards", "Ruby Heroes Award", "Rails Luminary"],
    demo: ["Demo: Something", "Demo of New Features", "Product Demo"],
    intro: ["Intro", "Introduction", "Opening Remarks", "Welcome", "Welcome:", "Welcome Talk", "Welcome Address", "Welcome to RubyConf", "Opening Session", "Opening Address"],
    outro: ["Outro", "Closing Remarks", "Closing Words", "Closing Session", "Closing Address"]
  }.freeze

  NON_INTRO_TITLES = ["Welcoming New Contributors to Your OSS Project"].freeze

  test "infers the kind from the title" do
    KIND_WITH_TITLES.each do |kind, titles|
      titles.each do |title|
        assert_equal kind, Talk::Kind.from_title(title), "expected #{title.inspect} to be #{kind}"
      end
    end
  end

  test "does not treat 'welcoming ...' as an intro" do
    NON_INTRO_TITLES.each do |title|
      assert_equal :talk, Talk::Kind.from_title(title), "expected #{title.inspect} to be talk"
    end
  end

  test "defaults to :talk for blank titles" do
    assert_equal :talk, Talk::Kind.from_title(nil)
    assert_equal :talk, Talk::Kind.from_title("")
  end
end
