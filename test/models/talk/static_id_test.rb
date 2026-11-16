# frozen_string_literal: true

require "test_helper"

class Talk::StaticIDTest < ActiveSupport::TestCase
  test "generate uses the speakers" do
    assert_equal "jane-doe-testconf-2024", generate(speakers: ["Jane Doe"])
    assert_equal "jane-doe-john-smith-testconf-2024", generate(speakers: ["Jane Doe", "John Smith"])
  end

  test "generate adds the kind after the speakers" do
    assert_equal "jane-doe-keynote-testconf-2024", generate(speakers: ["Jane Doe"], kind: "keynote")
  end

  test "generate excludes the default talk kind" do
    assert_equal "jane-doe-testconf-2024", generate(speakers: ["Jane Doe"], kind: "talk")
    assert_equal "jane-doe-john-smith-testconf-2024", generate(speakers: ["Jane Doe", "John Smith"], kind: "talk")
    assert_equal "building-things-testconf-2024", generate(kind: "talk")
  end

  test "generate ignores placeholder speakers" do
    assert_equal "building-things-testconf-2024", generate(speakers: ["TODO"])
  end

  test "generate falls back to the kind and title for more than two speakers" do
    assert_equal "keynote-building-things-testconf-2024", generate(speakers: ["A B", "C D", "E F"], kind: "keynote")
  end

  test "generate falls back to the kind and title without speakers" do
    assert_equal "keynote-building-things-testconf-2024", generate(kind: "keynote")
  end

  test "generate uses the title alone when it contains the kind" do
    assert_equal "opening-keynote-testconf-2024", generate(title: "Opening Keynote", kind: "keynote")
  end

  test "generate uses the title alone without speakers or kind" do
    assert_equal "building-things-testconf-2024", generate
  end

  test "generate parameterizes every part" do
    assert_equal "jose-garcia-testconf-2024", generate(speakers: ["José García"])
    assert_equal "hola-testconf-2024", generate(title: "¡Hola!")
  end

  private

  def generate(**attributes)
    Talk::StaticID.generate(event_slug: "testconf-2024", title: "Building Things", **attributes)
  end
end
