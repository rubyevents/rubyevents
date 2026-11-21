# frozen_string_literal: true

module Static
  # Names, aliases, slugs, GitHub handles and social handles each identify a single speaker
  #
  class UniqueSpeakersValidator < FileErrorsValidator
    UNIQUE_FIELDS = %w[slug github twitter speakerdeck mastodon bluesky].freeze

    private

    def file_errors(records)
      speakers = Static::Speaker.in_file(records.first.file_path, document: records.first.document)

      duplicate_names(speakers) + duplicate_fields(speakers) + duplicate_alias_slugs(speakers) + shared_identifiers(speakers)
    end

    def duplicate_names(speakers)
      same_name = speakers.same_name_duplicates.map do |name, count|
        [speakers.find_by(name: name), "Same name duplicate: #{name} (#{count} occurrences)", nil]
      end

      reversed = speakers.reversed_name_duplicates.map do |pair|
        [speakers.find_by(name: pair[0]), "Reversed name duplicate: #{pair[0]} ↔ #{pair[1]}", nil]
      end

      same_name + reversed
    end

    def duplicate_fields(speakers)
      UNIQUE_FIELDS.flat_map do |field|
        speakers.duplicates(field).map do |value, count|
          [speakers.find_by("#{field}": value), "Duplicate #{field}: #{value} (#{count} occurrences)", nil]
        end
      end
    end

    def duplicate_alias_slugs(speakers)
      main_slug_owners = {}
      alias_slug_owners = Hash.new { |hash, key| hash[key] = Set.new }

      speakers.each do |speaker|
        main_slug_owners[speaker["slug"]] = speaker["name"] if speaker["slug"]
        Array(speaker["aliases"]).each { |alias_entry| alias_slug_owners[alias_entry["slug"]] << speaker["name"] if alias_entry["slug"] }
      end

      shared = alias_slug_owners.select { |_slug, owners| owners.size > 1 }.map do |slug, owners|
        [speakers.find_by(slug: slug), "Alias slug '#{slug}' shared across speakers: #{owners.to_a.join(", ")}", nil]
      end

      conflicting = alias_slug_owners.filter_map do |slug, owners|
        main_owner = main_slug_owners[slug]
        next unless main_owner

        others = owners.reject { |owner| owner == main_owner }
        next if others.empty?

        [speakers.find_by(slug: slug), "Alias slug '#{slug}' on #{others.join(", ")} conflicts with main slug of '#{main_owner}'", nil]
      end

      shared + conflicting
    end

    def shared_identifiers(speakers)
      identifiers = Hash.new { |hash, key| hash[key] = [] }

      speakers.each do |speaker|
        name = speaker["name"]
        github = speaker["github"]

        identifiers[name.downcase] << {value: name, kind: "name", speaker: name, record: speaker} if name.present?
        identifiers[github.downcase] << {value: github, kind: "GitHub handle", speaker: name, record: speaker} if github.present?

        Array(speaker["aliases"]).each do |alias_entry|
          alias_name = alias_entry["name"] if alias_entry.is_a?(Hash)
          identifiers[alias_name.downcase] << {value: alias_name, kind: "alias", speaker: name, record: speaker} if alias_name.present?
        end
      end

      identifiers.values.filter_map do |uses|
        next if uses.map { |use| use[:speaker] }.uniq.size < 2

        description = uses.map { |use| %(#{use[:kind]} "#{use[:value]}" of "#{use[:speaker]}") }.join(", ")

        [uses.last[:record], "Speaker identifier used by more than one speaker: #{description}. Names, aliases, and GitHub handles must each identify a single speaker.", nil]
      end
    end
  end
end
