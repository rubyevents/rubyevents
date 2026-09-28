require "test_helper"
require "generators/event_base"
require "generators/tool_generation"

class ToolGenerationTest < ActiveSupport::TestCase
  GENERATOR_NAME = "Sample"
  GENERATED_TOOL_CONST = :"Generate#{GENERATOR_NAME}Tool"

  teardown do
    # Even though we're using an anonmyous generator class here in the test, we
    # still want to clean up the class constant set by the method under test itself
    if Object.const_defined?(GENERATED_TOOL_CONST)
      Object.send(:remove_const, GENERATED_TOOL_CONST)
    end
  end

  test "returns a RubyLLM::Tool subclass for each given generator" do
    tools = ToolGeneration.generate_tools([build_generator])

    assert_equal 1, tools.size
    assert_operator tools.first, :<, RubyLLM::Tool
  end

  test "sets the tool's desc from the generator's TOOL_DESC constant" do
    generator = build_generator(tool_desc: "Do the sample thing.")

    tool = ToolGeneration.generate_tools([generator]).first

    assert_equal "Do the sample thing.", tool.description
  end

  test "falls back to a generic desc when the generator has no TOOL_DESC" do
    generator = build_generator(tool_desc: nil)

    tool = ToolGeneration.generate_tools([generator]).first

    assert_equal "Runs the sample generator.", tool.description
  end

  test "builds tool params from the generator's Fields class_options" do
    tool = ToolGeneration.generate_tools([build_generator]).first

    assert_equal %i[event_series event title tags kind], tool.parameters.keys

    title_param = tool.parameters[:title]
    assert_equal "string", title_param.type.to_s
    assert_equal "Title of the thing", title_param.description
    assert title_param.required

    tags_param = tool.parameters[:tags]
    assert_equal "array", tags_param.type.to_s
    refute tags_param.required

    kind_param = tool.parameters[:kind]
    assert_equal "string", kind_param.type.to_s
    assert_equal "Kind of the thing", kind_param.description
    refute kind_param.required
  end

  test "registers a Generate<Type>Tool constant for the generator" do
    tool = ToolGeneration.generate_tools([build_generator]).first

    assert_equal tool, Object.const_get(GENERATED_TOOL_CONST)
  end

  private

  # Builds an anonymous Generators::EventBase subclass with one string, one array
  # and one enum field option. Sets TOOL_DESC if provided.
  def build_generator(tool_desc: "Do the sample thing.")
    generator = Class.new(Generators::EventBase) do
      class_option :title, type: :string, desc: "Title of the thing", group: "Fields", required: true
      class_option :tags, type: :array, desc: "Tags for the thing", group: "Fields"
      class_option :kind, type: :string, enum: %w[foo bar], desc: "Kind of the thing", group: "Fields"
    end

    generator.define_singleton_method(:name) { "#{GENERATOR_NAME}Generator" }
    generator.const_set(:TOOL_DESC, tool_desc) if tool_desc

    generator
  end
end
