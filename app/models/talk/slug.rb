# frozen_string_literal: true

class Talk
  module Slug
    module_function

    def candidates(static_slug:, title:, event_name:, language:, date:, speaker_slugs:, raw_title:)
      [
        static_slug&.parameterize,
        title.parameterize,
        join(title.parameterize, event_name&.parameterize),
        join(title.parameterize, language&.parameterize),
        join(title.parameterize, event_name&.parameterize, language&.parameterize),
        join(date.to_s.parameterize, title.parameterize),
        join(title.parameterize, *speaker_slugs),
        join(raw_title&.parameterize),
        join(date.to_s.parameterize, raw_title&.parameterize)
      ].reject(&:blank?).uniq
    end

    def unused(candidates, used:)
      candidates - used.to_a
    end

    def pick(candidates, used:)
      candidates.find { |candidate| !used.include?(candidate) }
    end

    def join(*parts)
      parts.compact.reject(&:blank?).join("-")
    end
  end
end
