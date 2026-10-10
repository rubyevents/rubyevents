# frozen_string_literal: true

require "rubocop"
require_relative "../../../../config/environment" # TODO: remove this

module RuboCop
  module Cop
    module RubyEvents
      # Runs the RubyEvents Static::Validations on data/**/*.yml files and
      # reports errors as RuboCop findings.
      class Validations < Base
        extend AutoCorrector

        def on_new_investigation
          investigate_rubyevents
        end

        def on_other_file
          investigate_rubyevents
        end

        private

        def investigate_rubyevents
          return unless data_yaml_file?

          file_path = processed_source.file_path
          document = Yerba.parse_file(file_path.to_s)

          ::Static::Validators::Validator.all_validator_classes.each do |validator_class|
            validator = validator_class.new(file_path:, document:)
            validator.errors.each do |error|
              build_offense(validator, error)
            end
          end
        end

        def data_yaml_file?
          file_path = processed_source.file_path

          return false unless file_path
          return false unless file_path.end_with?(".yml", ".yaml")

          file_path.include?("/data/") || file_path.start_with?("data/")
        end

        def build_offense(validator, error)
          add_offense(
            build_range(error),
            message: error.message,
            severity: :error
          ) do |corrector|
            validator.fix
          end
        end

        def build_range(error)
          buffer = processed_source.buffer

          begin_position = buffer.line_range(error.line).begin_pos + (error.column || 0)
          end_position = if error.end_column
            buffer.line_range(error.end_line).begin_pos + error.end_column
          else
            buffer.line_range(error.end_line).end_pos
          end

          Parser::Source::Range.new(buffer, begin_position, end_position)
        end
      end
    end
  end
end
