module RuboCop
  module Cop
    module RubyEvents
      # Flags YAML/Psych parsing and loading calls in favor of the Yerba gem,
      # which preserves comments, blank lines, and formatting when reading and
      # writing the YAML data files in data/.
      #
      # @example
      #   # bad
      #   YAML.load_file("data/speakers.yml")
      #   YAML.parse(content)
      #
      #   # good
      #   Yerba.parse_file("data/speakers.yml").to_h
      #   Yerba.parse(content)
      class PreferYerba < Base
        FILE_METHODS = %i[load_file safe_load_file unsafe_load_file parse_file].freeze
        CONTENT_METHODS = %i[load safe_load unsafe_load parse parse_stream load_stream].freeze

        RESTRICT_ON_SEND = (FILE_METHODS + CONTENT_METHODS).freeze

        MSG = "Use `Yerba.%<replacement>s` instead of `%<original>s`."

        def_node_matcher :yaml_call, <<~PATTERN
          (send (const {nil? cbase} {:YAML :Psych}) $_ ...)
        PATTERN

        def on_send(node)
          method_name = yaml_call(node)
          return unless method_name

          replacement = FILE_METHODS.include?(method_name) ? :parse_file : :parse

          add_offense(
            node,
            message: format(MSG, replacement: replacement, original: "#{node.receiver.source}.#{method_name}")
          )
        end
      end
    end
  end
end
