# frozen_string_literal: true

require "test_helper"

class Static::SpeakerSlugValidatorTest < ActiveSupport::TestCase
  test "flags a GitHub handle used as the slug" do
    errors = errors_for(<<~YAML)
      ---
      - name: Rachael Wright-Munn
        github: chaelcodes
        slug: chaelcodes
    YAML

    assert_equal [[4, "Slug must be the name parameterized, expected: rachael-wright-munn"]], errors
  end

  test "flags a slug that isn't parameterized" do
    errors = errors_for(<<~YAML)
      ---
      - name: Rachael Wright-Munn
        slug: RachaelWrightMunn
    YAML

    assert_equal [[3, "Slug must be the name parameterized, expected: rachael-wright-munn"]], errors
  end

  test "allows the parameterized name as the slug" do
    assert_empty errors_for(<<~YAML)
      ---
      - name: Rachael Wright-Munn
        github: chaelcodes
        slug: rachael-wright-munn
    YAML
  end

  test "allows the GitHub handle as the slug when the name can't be parameterized" do
    assert_empty errors_for(<<~YAML)
      ---
      - name: まつもとゆきひろ
        github: matz
        slug: matz
    YAML
  end

  test "flags a slug other than the GitHub handle when the name can't be parameterized" do
    errors = errors_for(<<~YAML)
      ---
      - name: まつもとゆきひろ
        github: matz
        slug: ruby
    YAML

    assert_equal [[4, "Name cannot be parameterized. Slug must be the GitHub handle, expected: matz."]], errors
  end

  test "allows any slug when the name can't be parameterized and there's no GitHub handle" do
    assert_empty errors_for(<<~YAML)
      ---
      - name: まつもとゆきひろ
        slug: yukihiro-matsumoto
    YAML
  end

  test "allows any slug for an alias whose name can't be parameterized" do
    assert_empty errors_for(<<~YAML)
      ---
      - name: NARUSE Yui
        github: nurse
        slug: naruse-yui
        aliases:
          - name: 成瀬ゆい
            slug: naruse-yui
    YAML
  end

  test "allows alias slugs that are their parameterized names" do
    assert_empty errors_for(<<~YAML)
      ---
      - name: Yukihiro "Matz" Matsumoto
        slug: yukihiro-matz-matsumoto
        aliases:
          - name: Matz
            slug: matz
          - name: Yukihiro 'Matz' Matsumoto
            slug: yukihiro-matz-matsumoto
          - name: Yukihiro Matsumoto
            slug: yukihiro-matsumoto
          - name: まつもとゆきひろ
            slug: yukihiro-matsumoto
    YAML
  end

  test "flags an alias slug that isn't its parameterized name" do
    errors = errors_for(<<~YAML)
      ---
      - name: Yukihiro "Matz" Matsumoto
        slug: yukihiro-matz-matsumoto
        aliases:
          - name: Matz
            slug: Matz
    YAML

    assert_equal [[6, "Slug must be the name parameterized, expected: matz"]], errors
  end

  private

  def errors_for(yaml)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "speakers.yml")
      File.write(path, yaml)

      Static::Speaker.in_file(path).flat_map do |speaker|
        speaker.valid?
        speaker.errors.map { |error| [speaker.error_location(error)&.start_line, error.full_message] }
      end
    end
  end
end
