# frozen_string_literal: true

require "test_helper"

class Static::Validators::ValidatorTest < ActiveSupport::TestCase
  test "finds the validators that can fix themselves" do
    fixable = Static::Validators::Validator.fixable_validators

    assert_includes fixable, Static::Validators::SponsorSlug
    assert_includes fixable, Static::Validators::TalkId
  end

  test "leaves out validators that only validate" do
    fixable = Static::Validators::Validator.fixable_validators

    assert_not_includes fixable, Static::Validators::Schema
    assert_not_includes fixable, Static::Validators::UniqueTalkIds
    assert_not_includes fixable, Static::Validators::TalkRenames
  end

  test "fix is an instance method, so the classes themselves never respond to it" do
    assert_not Static::Validators::TalkId.respond_to?(:fix)
    assert_not Static::Validators::SponsorSlug.respond_to?(:fix)
    assert Static::Validators::TalkId.method_defined?(:fix)
    assert Static::Validators::SponsorSlug.method_defined?(:fix)
  end

  test "returns every validator once, even when registered in several scopes" do
    fixable = Static::Validators::Validator.fixable_validators

    assert_equal fixable.uniq, fixable
    assert fixable.all? { |validator_class| validator_class.method_defined?(:fix) }
  end

  test "reads every scope" do
    scopes = [
      :cfp_validator_classes,
      :event_validator_classes,
      :involvement_validator_classes,
      :schedule_validator_classes,
      :series_validator_classes,
      :speaker_validator_classes,
      :sponsor_validator_classes,
      :venue_validator_classes,
      :video_validator_classes
    ]

    fixable = Static::Validators::Validator.fixable_validators

    scopes.each do |scope|
      expected = Static::Validators::Validator.send(scope).select { |validator_class| validator_class.method_defined?(:fix) }

      assert_equal expected.sort_by(&:name), (fixable & expected).sort_by(&:name), "#{scope} contributed no fixable validators"
    end
  end
end
