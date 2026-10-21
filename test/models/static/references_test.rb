require "test_helper"

class Static::ReferencesTest < ActiveSupport::TestCase
  test "a model nested in another model collects its records from the owning records" do
    recordings = Static::Talk::AlternativeRecording.all
    tiers = Static::Sponsor::Tier.all

    assert recordings.any?
    assert_equal [Static::Talk::AlternativeRecording], recordings.map(&:class).uniq
    assert_equal [Static::Talk], recordings.map { |recording| recording.parent.class }.uniq
    assert tiers.any?
    assert_equal [Static::Sponsor::Tier], tiers.map(&:class).uniq
  end

  test "nested records of another model stay out of the owning model's collection" do
    assert_equal [Static::Talk], Static::Talk.all.map(&:class).uniq
  end

  test "inbound_references collects the references other models declare to the model" do
    references = Static::Speaker.inbound_references

    assert_equal %w[Static::Involvement Static::Talk Static::Talk::AlternativeRecording], references.map { |reference| reference.record.class.name }.uniq.sort
    assert_equal %w[speakers users], references.map { |reference| reference.selector[/\A\w+/] }.uniq.sort
  end

  test "a reference knows the file and line of its value" do
    references = Static::Speaker.inbound_references.group_by { |reference| reference.record.class }

    references.each_value do |group|
      reference = group.first
      line = File.readlines(reference.file_path)[reference.line - 1]

      assert_includes line, reference.value
    end
  end

  test "a reference knows the selector of its value in the file" do
    references = Static::Speaker.inbound_references.group_by { |reference| reference.record.class }

    references.each_value do |group|
      reference = group.find { |candidate| candidate.record.nested? } || group.first

      assert_equal "#{reference.record.selector}.#{reference.selector}", reference.full_selector
      assert_equal reference.value, Yerba.parse_file(reference.file_path).value_at(reference.full_selector)
    end
  end
end
