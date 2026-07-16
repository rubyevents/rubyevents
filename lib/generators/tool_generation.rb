require "rails/generators"

class ToolGeneration
  # Generates RubyLLM tool classes for each Rails generator defined in
  # lib/generators.
  #
  # @return [Array<RubyLLM::Tool>]
  def self.generate_tools
    # Load all the generators
    Rails::Generators.sorted_groups

    Generators::EventBase.descendants.map do |klass|
      # Grab the generator's options that we've defined manually so that they
      # can be provided as params to the new tool class.
      options = klass.class_options.select do |option_key, option|
        option.group == "Fields"
      end

      tool = Class.new(RubyLLM::Tool) do
        options.each do |option_key, option|
          # Document each param for the tool using what is defined on the
          # corresponding generator option
          param(
            option_key.to_sym,
            desc: option.description,
            required: option.required,
            type: option.type
          )
        end
      end

      generator_type = klass.name.gsub("Generator", "").downcase

      # If an argument's value is provided, ensure that it gets passed to the
      # generator in the correct format. If it is not provided, discard it to
      # ensure fallback values in the generator code are used properly.
      argument_handling_code = options.map do |option_key, option|
        <<~METHOD
          if #{option_key}
            cli_options << ["#{option.switch_name}", *Array.wrap(#{option_key})]
          end
        METHOD
      end.join("\n")

      execute_method = <<~RUBY
        def execute(#{execute_params(options)})
          cli_options = []
          #{argument_handling_code}

          Rails::Generators.invoke(
            "#{generator_type}",
            cli_options.flatten,
            behavior: :invoke
          )
        end
      RUBY

      tool.class_eval(execute_method)

      Object.const_set(:"Generate#{generator_type.camelize}Tool", tool)
      tool
    end
  end

  def self.execute_params(options)
    required_params = options.select { |k, v| v.required }.keys.map { |k| "#{k}:" }
    optional_params = options.reject { |k, v| v.required }.keys.map { |k| "#{k}: nil" }
    (required_params + optional_params).join(", ")
  end
  private_class_method :execute_params
end
