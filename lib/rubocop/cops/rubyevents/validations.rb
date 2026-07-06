# frozen_string_literal: true

require "rubocop"
require_relative "../../../../config/environment" # TODO: remove this

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
          return unless data_yaml_file?

          self.class.load_rubyevents_environment!

          file_path = processed_source.file_path

          ::Static::Validators::Validator.all_validator_classes.each do |validator_class|
            validator_class.new(file_path:).errors.each do |error|
              build_offense(error)
            end
          end
        end

        def data_yaml_file?
          file_path = processed_source.file_path

          return false unless file_path
          return false unless file_path.end_with?(".yml", ".yaml")

          file_path.include?("/data/") || file_path.start_with?("data/")
        end

        def build_offense(error)
          range = build_range(error)
          add_offense(range, message: error.message, severity: :error)
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
