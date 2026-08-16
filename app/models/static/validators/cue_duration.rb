# frozen_string_literal: true

module Static
  module Validators
    module CueDuration
      module_function

      def duration_in_seconds(node)
        start_seconds = cue_to_seconds(node.value_at("start_cue"))
        end_seconds = cue_to_seconds(node.value_at("end_cue"))
        return nil if start_seconds.nil? || end_seconds.nil?

        duration = end_seconds - start_seconds
        duration.positive? ? duration : nil
      end

      def cue_to_seconds(cue)
        cue = cue.to_s.strip
        return nil if cue.empty? || cue == "TODO"
        return nil unless cue.match?(/\A\d+(:\d+)*\z/)

        cue.split(":").map(&:to_i).reverse.each_with_index.reduce(0) do |sum, (value, index)|
          sum + value * (60**index)
        end
      end
    end
  end
end
