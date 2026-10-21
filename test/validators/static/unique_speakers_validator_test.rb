# frozen_string_literal: true

require "test_helper"

class Static::UniqueSpeakersValidatorTest < ActiveSupport::TestCase
  test "unique names, slugs and GitHub handles produce no errors" do
    assert_empty lint_errors(<<~YAML)
      ---
      - name: Alice Smith
        slug: alice-smith
        github: alice-gh
      - name: Bob Jones
        slug: bob-jones
        github: bob-gh
    YAML
  end

  test "flags duplicate slugs" do
    errors = lint_errors(<<~YAML)
      ---
      - name: Alice
        slug: alice
      - name: Alice
        slug: alice
    YAML

    assert_includes errors, [2, "Duplicate slug: alice (2 occurrences)"]
  end

  test "flags duplicate GitHub handles" do
    errors = lint_errors(<<~YAML)
      ---
      - name: Alice
        slug: alice
        github: alicegithub
      - name: Alice Clone
        slug: alice-clone
        github: alicegithub
    YAML

    assert_includes errors, [2, "Duplicate github: alicegithub (2 occurrences)"]
  end

  test "flags same name duplicates" do
    errors = lint_errors(<<~YAML)
      ---
      - name: Alice Smith
        slug: alice-smith
      - name: Alice Smith
        slug: alice-smith
    YAML

    assert_includes errors, [2, "Same name duplicate: Alice Smith (2 occurrences)"]
  end

  test "flags reversed name duplicates" do
    errors = lint_errors(<<~YAML)
      ---
      - name: Alice Smith
        slug: alice-smith
      - name: Smith Alice
        slug: smith-alice
    YAML

    assert_equal [[2, "Reversed name duplicate: Alice Smith ↔ Smith Alice"]], errors
  end

  test "flags an alias name that is another speaker's name" do
    errors = lint_errors(<<~YAML).map(&:last)
      ---
      - name: Alice Smith
        slug: alice-smith
      - name: Bob Jones
        slug: bob-jones
        aliases:
          - name: Alice Smith
            slug: alice-smith-alias
    YAML

    assert_includes errors, "Same name duplicate: Alice Smith (2 occurrences)"
    assert_includes errors, %(Speaker identifier used by more than one speaker: name "Alice Smith" of "Alice Smith", alias "Alice Smith" of "Bob Jones". Names, aliases, and GitHub handles must each identify a single speaker.)
  end

  test "flags an alias name shared across speakers" do
    errors = lint_errors(<<~YAML).map(&:last)
      ---
      - name: Alice Smith
        slug: alice-smith
        aliases:
          - name: A. Smith
            slug: a-smith-1
      - name: Bob Jones
        slug: bob-jones
        aliases:
          - name: A. Smith
            slug: a-smith-1
    YAML

    assert_includes errors, "Same name duplicate: A. Smith (2 occurrences)"
    assert_includes errors, "Alias slug 'a-smith-1' shared across speakers: Alice Smith, Bob Jones"
  end

  test "flags an alias slug that is another speaker's main slug" do
    errors = lint_errors(<<~YAML)
      ---
      - name: Alice Smith
        slug: alice-smith
      - name: Bob Jones
        slug: bob-jones
        aliases:
          - name: Alice-Smith
            slug: alice-smith
    YAML

    assert_equal [[2, "Alias slug 'alice-smith' on Bob Jones conflicts with main slug of 'Alice Smith'"]], errors
  end

  test "reports each kind of duplicate" do
    errors = lint_errors(<<~YAML).map(&:last)
      ---
      - name: Alice Smith
        slug: alice-smith
      - name: Alice Smith
        slug: alice-smith-2
      - name: Bob Jones
        slug: bob-jones
      - name: Jones Bob
        slug: jones-bob
    YAML

    assert_includes errors, "Same name duplicate: Alice Smith (2 occurrences)"
    assert_includes errors, "Reversed name duplicate: Bob Jones ↔ Jones Bob"
  end

  test "allows identifiers repeated within the same speaker" do
    assert_empty lint_errors(<<~YAML)
      ---
      - name: "buty4649"
        github: "buty4649"
        slug: "buty4649"
      - name: "Hiroshi SHIBATA"
        github: "hsbt"
        slug: "hiroshi-shibata"
        aliases:
          - name: "Hiroshi Shibata"
            slug: "hiroshi-shibata"
    YAML
  end

  test "flags a name that is another speaker's GitHub handle" do
    errors = lint_errors(<<~YAML)
      ---
      - name: "Keith Gaddis"
        github: "karmajunkie"
        slug: "keith-gaddis"
      - name: "karmajunkie"
        github: ""
        slug: "karmajunkie"
    YAML

    assert_equal [[5, %(Speaker identifier used by more than one speaker: GitHub handle "karmajunkie" of "Keith Gaddis", name "karmajunkie" of "karmajunkie". Names, aliases, and GitHub handles must each identify a single speaker.)]], errors
  end

  test "flags an alias that is another speaker's GitHub handle, ignoring case" do
    errors = lint_errors(<<~YAML).map(&:last)
      ---
      - name: "Pablo Astigarraga"
        github: "pote"
        slug: "pablo-astigarraga"
      - name: "Someone Else"
        github: ""
        slug: "someone-else"
        aliases:
          - name: "Pote"
            slug: "pote"
    YAML

    assert_equal 1, errors.size
    assert_includes errors.first, %(alias "Pote" of "Someone Else")
  end

  test "flags an alias that is another speaker's name, ignoring case" do
    errors = lint_errors(<<~YAML).map(&:last)
      ---
      - name: "Jane Doe"
        github: ""
        slug: "jane-doe"
      - name: "Janet Doe"
        github: ""
        slug: "janet-doe"
        aliases:
          - name: "jane doe"
            slug: "jane-doe"
    YAML

    assert_includes errors.join("\n"), %(name "Jane Doe" of "Jane Doe", alias "jane doe" of "Janet Doe")
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
