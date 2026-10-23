# frozen_string_literal: true

module Static
  module Validators
    module MeetupNaming
      IGNORED_EVENT_IDS = %w[
        rubyevents
      ].freeze

      def self.ignored?(event)
        event.nil? || event["id"].to_s.in?(IGNORED_EVENT_IDS)
      end
    end
  end
end
