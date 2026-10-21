# frozen_string_literal: true

module Static
  # Every name in the attribute is a speaker in data/speakers.yml (by name, alias or GitHub handle)
  #
  class SpeakerExistsValidator < ActiveModel::EachValidator
    Reference = Data.define(:value)

    # The value is read raw: the attribute's reader resolves the references to speakers
    def validate_each(record, attribute, _speakers)
      missing(record[attribute]).each do |name, index|
        record.errors.add(:base, :unknown_speaker, message: %(Speaker "#{name}" not found in data/speakers.yml), at: "#{attribute}[#{index}]")
      end
    end

    def fix(record)
      attributes.sum do |attribute|
        names = missing(record[attribute]).map(&:first)
        next 0 if names.empty?

        added = Static::Speaker.add_missing_speakers(names.map { |name| Reference.new(value: name) })
        Static::Speaker.save!

        added.size
      end
    end

    private

    def missing(names)
      Array(names).each_with_index.select { |name, _index| name.present? && !Static::Speaker.known_reference?(name) }
    end
  end
end
