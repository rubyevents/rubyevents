# frozen_string_literal: true

require "test_helper"

class Static::SimilarSpeakerNamesValidatorTest < ActiveSupport::TestCase
  test "flags a similar-named speaker with no social handle" do
    errors = lint_errors(<<~YAML)
      - name: Pat Shaughnessy
        slug: pat-shaughnessy
        github: pat
      - name: Pat Saughnessy
        slug: pat-saughnessy
        github: ""
    YAML

    assert_equal [[4, %("Pat Saughnessy" closely matches "Pat Shaughnessy" but has no social handle (#{Static::Speaker::SOCIAL_HANDLE_FIELDS.join(", ")}). Add one to disambiguate whether they are the same person.)]], errors
  end

  test "does not flag when the similar-named speaker has any social handle" do
    assert_empty lint_errors(<<~YAML)
      - name: Pat Shaughnessy
        slug: pat-shaughnessy
        github: pat
      - name: Pat Saughnessy
        slug: pat-saughnessy
        mastodon: "@pat@ruby.social"
    YAML
  end

  test "flags both members when neither has a handle" do
    errors = lint_errors(<<~YAML)
      - name: James Edward-Jones
        slug: james-edward-jones
        github: ""
      - name: James Edwards-Jones
        slug: james-edwards-jones
        github: ""
    YAML

    assert_equal [1, 4], errors.map(&:first)
  end

  test "does not flag distinct names lacking handles" do
    assert_empty lint_errors(<<~YAML)
      - name: Aaron Patterson
        slug: aaron-patterson
        github: ""
      - name: Yukihiro Matsumoto
        slug: yukihiro-matsumoto
        github: ""
    YAML
  end

  private

  def lint_errors(yaml)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "speakers.yml")
      File.write(path, yaml)

      Static::Speaker.in_file(path).flat_map do |speaker|
        speaker.valid?(:lint)
        speaker.errors.map { |error| [speaker.error_location(error)&.start_line, error.full_message] }
      end
    end
  end
end
