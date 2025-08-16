# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: events
#
#  id              :integer          not null, primary key
#  date            :date
#  city            :string
#  country_code    :string
#  organisation_id :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  name            :string           default(""), not null
#  slug            :string           default(""), not null
#
# rubocop:enable Layout/LineLength
require "test_helper"

class YouTube::VideoMetadataTest < ActiveSupport::TestCase
  test "remove the event name from the title and preserve the keynote mention" do
    metadata = OpenStruct.new({
      title: "RailsConf 2021: Keynote: Eileen M. Uchitelle - All the Things I Thought I Couldn't Do",
      description: "RailsConf 2021 lorem ipsum"
    })
    results = YouTube::VideoMetadata.new(metadata: metadata, event_name: "RailsConf 2021")
    assert_equal "Keynote: Eileen M. Uchitelle - All the Things I Thought I Couldn't Do", results.cleaned.title
    assert results.keynote?
  end

  test "extract mutiple speakers" do
    metadata = OpenStruct.new({
      title: "RailsConf 2022 - Spacecraft! The care and keeping of a legacy ... by Annie Lydens & Jenny Allar",
      description: "lorem ipsum"
    })
    results = YouTube::VideoMetadata.new(metadata: metadata, event_name: "RailsConf 2022").cleaned
    assert_equal "Spacecraft! The care and keeping of a legacy ...", results.title
    assert_equal ["Annie Lydens", "Jenny Allar"], results.speakers
  end

  test "extract mutiple speakers with 'and' in the name" do
    metadata = OpenStruct.new({
      title: "RubyConf AU 2013: From Stubbies to Longnecks by Geoffrey Giesemann",
      description: "lorem ipsum"
    })
    results = YouTube::VideoMetadata.new(metadata: metadata, event_name: "RubyConf AU 2013").cleaned
    assert_equal "From Stubbies to Longnecks", results.title
    assert_equal ["Geoffrey Giesemann"], results.speakers
  end

  test "lighting talks" do
    metadata = OpenStruct.new({
      title: "RubyConf AU 2013: Lightning Talks",
      description: "lorem ipsum"
    })

    results = YouTube::VideoMetadata.new(metadata: metadata, event_name: "RubyConf AU 2013").cleaned
    assert_equal "Lightning Talks", results.title
    assert_equal [], results.speakers
  end

  test "speaker name containing and" do
    metadata = OpenStruct.new({
      title: "RubyConf AU 2017 - Writing a Gameboy emulator in Ruby, by Colby Swandale"
    })

    results = YouTube::VideoMetadata.new(metadata: metadata, event_name: "RubyConf AU 2017").cleaned
    assert_equal ["Colby Swandale"], results.speakers
    assert_equal "Writing a Gameboy emulator in Ruby", results.title
  end

  # test "speaker name containing &" do
  #   metadata = OpenStruct.new({
  #     title: "RubyConf AU 2017 - VR backend rails vs serverless: froth or future? Ram Ramakrishnan & Janet Brown"
  #   })

  #   results = YouTube::VideoMetadata.new(metadata: metadata, event_name: "RubyConf AU 2017").cleaned
  #   assert_equal ["Ram Ramakrishnan", "Janet Brown"], results.speakers
  #   assert_equal "VR backend rails vs serverless: froth or future?", results.title
  # end

  # test "By separator should be case insensitive" do
  #   metadata = OpenStruct.new({
  #     title: "RubyConf AU 2017 - Simple and Awesome Database Tricks, By Barrett Clark"
  #   })

  #   results = YouTube::VideoMetadata.new(metadata: metadata, event_name: "RubyConf AU 2017").cleaned
  #   assert_equal ["Barrett Clark"], results.speakers
  #   assert_equal "Simple and Awesome Database Tricks", results.title
  # end
end
