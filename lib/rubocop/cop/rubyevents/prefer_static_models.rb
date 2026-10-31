module RuboCop
  module Cop
    module RubyEvents
      # Flags raw Yerba parsing in favor of the `Static::*` models, which read
      # the data files through `Yerba::Record` and report value locations with
      # `source_location`.
      #
      # @example
      #   # bad
      #   Yerba.parse_file(@file_path)["start_date"]
      #
      #   # good
      #   Static::Event.in_file(@file_path, document: @document).first["start_date"]
      #
      class PreferStaticModels < Base
        RESTRICT_ON_SEND = %i[parse_file parse].freeze

        MSG = "Use the `Static::*` models instead of `Yerba.%<method>s`, like `Static::Event.in_file(path, document: @document)`."

        def_node_matcher :yerba_parse, <<~PATTERN
          (send (const {nil? cbase} :Yerba) $_ ...)
        PATTERN

        def on_send(node)
          method_name = yerba_parse(node)
          return unless method_name

          add_offense(node, message: format(MSG, method: method_name))
        end
      end
    end
  end
end
