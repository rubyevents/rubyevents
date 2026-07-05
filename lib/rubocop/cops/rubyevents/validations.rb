# frozen_string_literal: true

require "rubocop"
require_relative "../../../../config/environment"

module RuboCop
  module Cop
    module RubyEvents
      # Runs the RubyEvents Static::Validations on data/**/*.yml files and
      # reports errors as RuboCop findings.
      #
      # This cop acts as a bridge, running all enabled RubyEvents rules in a single
      # pass and mapping the results into RuboCop's offense system.
      #
      # @example
      #   # .rubocop.yml
      #   RubyEvents/Validations:
      #     Enabled: true
      #
      class Validations < Base
        def on_new_investigation
          investigate_rubyevents
        end

        def on_other_file
          investigate_rubyevents
        end

        private

        def investigate_rubyevents
          file_path = processed_source.file_path

          ::Static::Validators::Validator.all_validator_classes.each do |validator_class|
            validator_class.new(file_path:).errors.each do |error|
              build_offense(error)
            end
          end
        end

        def build_offense(offense)
          range = build_range(offense)
          add_offense(range, message: offense.message, severity: :error)
        end

        def build_range(offense)
          buffer = processed_source.buffer

          begin_position = buffer.line_range(offense.line).begin_pos
          end_position = buffer.line_range(offense.end_line).end_pos

          Parser::Source::Range.new(buffer, begin_position, end_position)
        end
      end
    end
  end
end
