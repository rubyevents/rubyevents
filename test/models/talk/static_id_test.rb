# frozen_string_literal: true

require "test_helper"

class Talk::StaticIDTest < ActiveSupport::TestCase
  test "speaker_id uses the parameterized speaker name" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things", speakers: ["Jane Doe"])

    assert_equal "jane-doe-testconf-2024", id.speaker_id
  end

  test "speaker_id transliterates accented speaker names" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Hola", speakers: ["José García"])

    assert_equal "jose-garcia-testconf-2024", id.speaker_id
  end

  test "speaker_id joins two speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Pairing", speakers: ["Jane Doe", "John Smith"])

    assert_equal "jane-doe-john-smith-testconf-2024", id.speaker_id
  end

  test "speaker_id uses the kind for more than two speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "The Future of Ruby", kind: "panel", speakers: ["A B", "C D", "E F"])

    assert_equal "panel-testconf-2024", id.speaker_id
  end

  test "speaker_id falls back to the title for a plain talk without speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things")

    assert_equal "building-things-testconf-2024", id.speaker_id
  end

  test "speaker_id ignores TODO placeholder speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things", speakers: ["TODO"])

    assert_equal "building-things-testconf-2024", id.speaker_id
  end

  test "kind_id adds the dasherized kind after the speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Tiny Things", kind: "lightning_talk", speakers: ["Jane Doe"])

    assert_equal "jane-doe-lightning-talk-testconf-2024", id.kind_id
  end

  test "kind_id infers the kind from the title when not given" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Keynote: Big Things", speakers: ["Jane Doe"])

    assert_equal "jane-doe-keynote-testconf-2024", id.kind_id
  end

  test "kind_id matches speaker_id for a plain talk" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things", speakers: ["Jane Doe"])

    assert_equal id.speaker_id, id.kind_id
  end

  test "title_id uses the title in slug form" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things", speakers: ["Jane Doe"])

    assert_equal "building-things-testconf-2024", id.title_id
  end

  test "candidates lists the unique ids in priority order" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Keynote: Big Things", speakers: ["Jane Doe"])

    assert_equal ["jane-doe-testconf-2024", "jane-doe-keynote-testconf-2024", "keynote-big-things-testconf-2024"], id.candidates
  end

  test "candidates collapses for a plain talk without speakers" do
    id = Talk::StaticID.new(event_slug: "testconf-2024", title: "Building Things")

    assert_equal ["building-things-testconf-2024"], id.candidates
  end
end
