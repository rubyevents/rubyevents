# frozen_string_literal: true

require "test_helper"

class Static::SpeakerAliasesValidatorTest < ActiveSupport::TestCase
  test "allows aliases that differ from the GitHub handle" do
    assert_empty errors_for(<<~YAML)
      ---
      - name: "Ryosuke Uchida"
        github: "ryosk7"
        slug: "ryosuke-uchida"
        aliases:
          - name: "Ryosuke"
            slug: "ryosuke"
    YAML
  end

  test "flags an alias that is the speaker's own GitHub handle, ignoring case" do
    errors = errors_for(<<~YAML)
      ---
      - name: "Ryosuke Uchida"
        github: "ryosk7"
        slug: "ryosuke-uchida"
        aliases:
          - name: "RyoSK7"
            slug: "ryosk7"
    YAML

    assert_equal [[2, %(Alias "RyoSK7" on "Ryosuke Uchida" is redundant, it's already the GitHub handle and GitHub handles act as aliases.)]], errors
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
