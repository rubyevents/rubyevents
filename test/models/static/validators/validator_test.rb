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

  test "returns every validator once, even when registered in several scopes" do
    fixable = Static::Validators::Validator.fixable_validators

    assert_equal fixable.uniq, fixable
    assert fixable.all? { |validator_class| validator_class.method_defined?(:fix) }
  end
end
