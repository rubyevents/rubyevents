require "test_helper"
require "rubocop"
require "rubocop/cop/rubyevents/prefer_yerba"

class RuboCop::Cop::RubyEvents::PreferYerbaTest < ActiveSupport::TestCase
  def offenses(source)
    config = RuboCop::Config.new({"RubyEvents/PreferYerba" => {"Enabled" => true}})
    cop = RuboCop::Cop::RubyEvents::PreferYerba.new(config)
    processed_source = RuboCop::ProcessedSource.new(source, 3.4, "(test)")

    RuboCop::Cop::Team.new([cop], config).investigate(processed_source).offenses
  end

  test "flags YAML file loading methods" do
    %w[load_file safe_load_file unsafe_load_file parse_file].each do |method|
      result = offenses(%(YAML.#{method}("data/speakers.yml")))

      assert_equal 1, result.size
      assert_equal "Use `Yerba.parse_file` instead of `YAML.#{method}`.", result.first.message.sub(/\ARubyEvents\/PreferYerba: /, "")
    end
  end

  test "flags YAML content parsing methods" do
    %w[load safe_load unsafe_load parse parse_stream load_stream].each do |method|
      result = offenses(%(YAML.#{method}(content)))

      assert_equal 1, result.size
      assert_equal "Use `Yerba.parse` instead of `YAML.#{method}`.", result.first.message.sub(/\ARubyEvents\/PreferYerba: /, "")
    end
  end

  test "flags Psych and top-level constant references" do
    assert_equal 1, offenses(%(Psych.load_file("file.yml"))).size
    assert_equal 1, offenses(%(::YAML.load_file("file.yml"))).size
  end

  test "does not flag Yerba or unrelated calls" do
    assert_empty offenses(%(Yerba.parse_file("data/speakers.yml")))
    assert_empty offenses(%(YAML.dump(data)))
    assert_empty offenses(%(JSON.parse(content)))
    assert_empty offenses(%(parse_file("file.yml")))
  end
end
