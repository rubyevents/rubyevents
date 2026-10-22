# frozen_string_literal: true

module Static
  module Validators
    module MeetupNaming
      # Events with kind "meetup" that are not a local meetup group, so the meetup
      # naming rules don't apply to them.
      IGNORED_EVENT_IDS = %w[
        rubyevents
      ].freeze

      def self.ignored?(event)
        event.nil? || event["id"].to_s.in?(IGNORED_EVENT_IDS)
      end
    end
  end
end
