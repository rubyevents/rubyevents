# frozen_string_literal: true

module Static
  # A talk lists each speaker once. Names are resolved through data/speakers.yml, so a speaker's name and one of
  # their aliases count as the same speaker, just like the import does. Otherwise the import fails to save the talk,
  # because a user can only be linked to it once.
  #
  class UniqueTalkSpeakersValidator < ActiveModel::Validator
    def validate(talk)
      names = Array(talk["speakers"]).map { |name| name.to_s.strip }
      indexes = names.each_index.reject { |index| names[index].empty? }
      duplicates = indexes.group_by { |index| speaker_names.fetch(names[index], names[index]) }.select { |_, group| group.many? }

      duplicates.each do |speaker, group|
        listed = group.map { |index| names[index] }.uniq.map { |name| %("#{name}") }.join(", ")

        talk.errors.add(:base, %(speaker "#{speaker}" is listed #{group.size} times (as #{listed}). Remove the duplicate or point it at the right speaker in data/speakers.yml.), at: "speakers[#{group.second}]")
      end
    end

    private

    # Every name and alias => the speaker's name
    def speaker_names
      Yerba::Record::Validations.cached(self.class, :speaker_names) do
        Static::Speaker.all.each_with_object({}) do |speaker, names|
          name = speaker["name"].to_s.strip
          names[name] = name

          Array(speaker["aliases"]).each do |alias_data|
            names[alias_data["name"].to_s.strip] ||= name if alias_data.is_a?(Hash)
          end
        end
      end
    end
  end
end
