# frozen_string_literal: true

module Static
  class SpeakersFile
    attr_reader :document

    SPEAKERS_PATH = "data/speakers.yml"
    VIDEOS_GLOB = "data/**/videos.yml"
    INVOLVEMENTS_GLOB = "data/**/involvements.yml"

    VIDEO_SPEAKER_SELECTORS = [
      "[].speakers[]",
      "[].alternative_recordings[].speakers[]",
      "[].talks[].speakers[]",
      "[].talks[].alternative_recordings[].speakers[]"
    ].freeze

    def initialize(path = Rails.root.join(SPEAKERS_PATH).to_s)
      @document = Yerba.parse_file(path)
    end

    def count
      document.root.length
    end
    alias_method :length, :count

    def names
      document.pluck(:name)
    end

    def slugs
      document.pluck(:slug)
    end

    def aliases
      document.value_at("[].aliases[].name") || []
    end

    def known_names
      @known_names ||= Set.new(names + aliases)
    end

    def index_by(field)
      @indexes ||= {}

      @indexes[field] ||= begin
        result = {}

        document.value_at("").each_with_index do |entry, index|
          result[entry[field.to_s]] = index if entry.is_a?(Hash) && entry[field.to_s]
        end

        result
      end
    end

    def find_by(name: nil, slug: nil, github: nil)
      index = (slug && index_by(:slug)[slug]) ||
        (github && index_by(:github)[github]) ||
        (name && index_by(:name)[name])

      document[index] if index
    end

    def where(**criteria)
      document.where(**criteria)
    end

    def add(name:, github: "", slug: nil, **attributes)
      slug ||= name.parameterize

      entry = {name: name, github: github, slug: slug}
      entry.merge!(attributes.reject { |_, value| value.nil? || value.to_s.empty? })

      document << entry

      entry
    end

    def all_speaker_references
      @all_speaker_references ||= begin
        video_refs = VIDEO_SPEAKER_SELECTORS.flat_map { |selector| Yerba::Collection.get(videos_glob, selector) }
        involvement_refs = Yerba::Collection.get(involvements_glob, "[].users[]")

        (video_refs + involvement_refs).reject { |scalar| scalar.value.blank? }
      end
    end

    def all_referenced_names
      @all_referenced_names ||= Set.new(all_speaker_references.map(&:value))
    end

    def missing_speaker_references
      all_speaker_references.reject { |scalar| known_names.include?(scalar.value) }
    end

    def missing_speakers
      missing_speaker_references.map(&:value).uniq.sort
    end

    def orphaned_speakers
      orphaned_entries.map { |_index, name| name }
    end

    def remove_orphaned_speakers!
      entries = orphaned_entries

      return [] if entries.empty?

      entries.map(&:first).reverse_each { |index| document.root.delete_at(index) }

      entries.map(&:last)
    end

    def add_missing_speakers
      missing = missing_speakers

      entries = missing.map do |name|
        {name: name, github: "", slug: name.parameterize}
      end

      document.concat(entries) if entries.any?

      missing
    end

    def duplicate_slugs
      slugs.tally.select { |_, count| count > 1 }
    end

    def duplicate_githubs
      document.pluck(:github).select(&:present?).tally.select { |_, count| count > 1 }
    end

    def duplicates(field)
      document.pluck(field.to_sym).select(&:present?).tally.select { |_, count| count > 1 }
    end

    def same_name_duplicates
      names.tally.select { |_, count| count > 1 }
    end

    def reversed_name_duplicates
      name_set = Set.new(names.map(&:downcase))

      names.each_with_object({}) do |name, result|
        next unless name.include?(" ")

        reversed = name.split(" ").reverse.join(" ")

        next if reversed.downcase == name.downcase
        next unless name_set.include?(reversed.downcase)

        key = [name, reversed].sort
        result[key] ||= key
      end.values
    end

    def save!
      document.sort(by: :name)
      document.save!(apply: true)
    end

    def changed?
      document.changed?
    end

    private

    def videos_glob
      Rails.root.join(VIDEOS_GLOB).to_s
    end

    def involvements_glob
      Rails.root.join(INVOLVEMENTS_GLOB).to_s
    end

    def orphaned_entries
      referenced = all_referenced_names
      all_values = document.value_at("")

      all_values.each_with_index.filter_map do |entry, index|
        next unless entry.is_a?(Hash)

        entry_names = [entry["name"]].compact
        Array(entry["aliases"]).each { |a| entry_names << a["name"] if a.is_a?(Hash) }

        [index, entry["name"]] if entry_names.none? { |name| referenced.include?(name) }
      end
    end
  end
end
