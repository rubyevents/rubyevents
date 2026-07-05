# frozen_string_literal: true

require "lint_roller"
require_relative "../cops/rubyevents_cops"

module RuboCop
  module RubyEvents
    class Plugin < LintRoller::Plugin
      CONFIG_PATH = File.expand_path("default.yml", __dir__).freeze

      def about
        LintRoller::About.new(
          name: "rubocop-rubyevents",
          version: 1.0,
          homepage: "https://rubyevents.org",
          description: "RuboCop integration for our yaml file validations"
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: config_path
        )
      end

      private

      def config_path
        CONFIG_PATH
      end
    end
  end
end
