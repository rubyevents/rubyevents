# frozen_string_literal: true

module Static
  # A speaker's slug (and each alias slug) is its name parameterized, or the GitHub handle when the
  # name can't be parameterized
  #
  class SpeakerSlugValidator < ActiveModel::Validator
    def validate(speaker)
      check(speaker, speaker["name"], speaker["slug"], speaker["github"], "slug")

      Array(speaker["aliases"]).each_with_index do |alias_entry, index|
        check(speaker, alias_entry["name"], alias_entry["slug"], nil, "aliases[#{index}].slug") if alias_entry.is_a?(Hash)
      end
    end

    private

    def check(speaker, name, slug, github, at)
      expected = name.to_s.parameterize
      return if slug == expected

      if expected.empty?
        return if github.blank?

        expected = github.to_s.parameterize
        return if slug == expected

        speaker.errors.add(:base, "Name cannot be parameterized. Slug must be the GitHub handle, expected: #{expected}.", at: at)
      else
        speaker.errors.add(:base, "Slug must be the name parameterized, expected: #{expected}", at: at)
      end
    end
  end
end
