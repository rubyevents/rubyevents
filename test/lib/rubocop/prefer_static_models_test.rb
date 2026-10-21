require "test_helper"
require "rubocop"
require "rubocop/cop/rubyevents/prefer_static_models"

class RuboCop::Cop::RubyEvents::PreferStaticModelsTest < ActiveSupport::TestCase
  def offenses(source)
    config = RuboCop::Config.new({"RubyEvents/PreferStaticModels" => {"Enabled" => true}})
    cop = RuboCop::Cop::RubyEvents::PreferStaticModels.new(config)
    processed_source = RuboCop::ProcessedSource.new(source, 3.4, "(test)")

    RuboCop::Cop::Team.new([cop], config).investigate(processed_source).offenses
  end

  test "flags Yerba.parse_file and Yerba.parse" do
    %w[parse_file parse].each do |method|
      result = offenses(%(Yerba.#{method}(@file_path)))

      assert_equal 1, result.size
      assert_equal "Use the `Static::*` models instead of `Yerba.#{method}`, like `Static::Event.in_file(path, document: @document)`.", result.first.message.sub(/\ARubyEvents\/PreferStaticModels: /, "")
    end
  end

  test "flags the top-level constant reference" do
    assert_equal 1, offenses(%(::Yerba.parse_file("event.yml"))).size
  end

  test "does not flag the Static models or unrelated calls" do
    assert_empty offenses(%(Static::Event.in_file(@file_path, document: @document).first))
    assert_empty offenses(%(Yerba::Selector.parse("[].id")))
    assert_empty offenses(%(JSON.parse(content)))
  end
end
