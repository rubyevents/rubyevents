# frozen_string_literal: true

module Static
  # GitHub handles act as aliases, so an alias that's the speaker's own handle is redundant
  #
  class SpeakerAliasesValidator < ActiveModel::EachValidator
    def validate_each(speaker, _attribute, aliases)
      github = speaker["github"]
      return if github.blank?

      Array(aliases).each do |alias_entry|
        next unless alias_entry.is_a?(Hash) && alias_entry["name"]&.casecmp?(github)

        speaker.errors.add(:base, %(Alias "#{alias_entry["name"]}" on "#{speaker["name"]}" is redundant, it's already the GitHub handle and GitHub handles act as aliases.))
      end
    end
  end
end
