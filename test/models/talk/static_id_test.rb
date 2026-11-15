# frozen_string_literal: true

require "test_helper"

class Talk::StaticIDTest < ActiveSupport::TestCase
  test "generate uses the parameterized speaker name" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things", speakers: ["Jane Doe"])

    assert_equal "jane-doe-testconf-2024", id.generate
  end

  test "generate transliterates accented speaker names" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Hola", speakers: ["José García"])

    assert_equal "jose-garcia-testconf-2024", id.generate
  end

  test "generate joins two speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Pairing", speakers: ["Jane Doe", "John Smith"])

    assert_equal "jane-doe-john-smith-testconf-2024", id.generate
  end

  test "generate uses the kind for more than two speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "The Future of Ruby", kind: "panel", speakers: ["A B", "C D", "E F"])

    assert_equal "panel-the-future-of-ruby-testconf-2024", id.generate
  end

  test "generate falls back to the title for a plain talk without speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things")

    assert_equal "building-things-testconf-2024", id.generate
  end

  test "generate ignores TODO placeholder speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things", speakers: ["TODO"])

    assert_equal "building-things-testconf-2024", id.generate
  end

  test "generate adds the dasherized kind after the speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Tiny Things", kind: "lightning_talk", speakers: ["Jane Doe"])

    assert_equal "jane-doe-lightning-talk-testconf-2024", id.generate
  end

  test "generate skips the kind if the title already has it" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Lightning Talk: Tiny Things", kind: "lightning_talk", speakers: ["TODO"])

    assert_equal "lightning-talk-tiny-things-testconf-2024", id.generate
  end

  test "generate skips the kind if the title ends with it" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Tiny Things Lightning Talk", kind: "lightning_talk")

    assert_equal "tiny-things-lightning-talk-testconf-2024", id.generate
  end

  test "generate skips the kind if the title contains it" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Ruby Workshop for Beginners", kind: "workshop")

    assert_equal "ruby-workshop-for-beginners-testconf-2024", id.generate
  end

  test "generate uses the title for an intro without speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Welcome and Introduction", kind: "intro")

    assert_equal "welcome-and-introduction-testconf-2024", id.generate
  end

  test "generate uses the kind and title for an intro with speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Welcome to TestConf", kind: "intro", speakers: ["Jane Doe"])

    assert_equal "intro-welcome-to-testconf-testconf-2024", id.generate
  end
end
