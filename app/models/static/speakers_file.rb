# frozen_string_literal: true

module Static
  class SpeakersFile
    attr_reader :document

    SPEAKERS_PATH = "data/speakers.yml"
    VIDEOS_GLOB = "data/**/videos.yml"
    INVOLVEMENTS_GLOB = "data/**/involvements.yml"

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
      document.get("[].aliases[].name") || []
    end

    def known_names
      @known_names ||= Set.new(names + aliases)
    end

    def find_by(name: nil, slug: nil, github: nil)
      (slug && document.find_by(slug: slug)) ||
        (github && document.find_by(github: github)) ||
        (name && document.find_by(name: name))
    end

    def where(**criteria)
      document.where(**criteria)
    end

    def add(name:, slug: nil, github: "", **attributes)
      slug ||= name.parameterize

      entry = {name: name, slug: slug, github: github}
      entry.merge!(attributes.reject { |_, value| value.nil? || value.to_s.empty? })

      document << entry
      entry
    end

    def all_referenced_names
      @all_referenced_names ||= begin
        video_speakers = Yerba::Collection.get(videos_glob, "[].speakers[]") || []
        sub_talk_speakers = Yerba::Collection.get(videos_glob, "[].talks[].speakers[]") || []
        involvement_users = Yerba::Collection.get(involvements_glob, "[].users[]") || []

        Set.new(video_speakers + sub_talk_speakers + involvement_users)
      end
    end

    def missing_speakers
      all_referenced_names.reject { |name| name.empty? || known_names.include?(name) }.sort
    end

    def orphaned_speakers
      referenced = all_referenced_names
      all_values = document.get_value("")

      all_values.filter_map do |entry|
        next unless entry.is_a?(Hash)

        entry_names = [entry["name"]].compact
        Array(entry["aliases"]).each { |a| entry_names << a["name"] if a.is_a?(Hash) }

        entry["name"] if entry_names.none? { |name| referenced.include?(name) }
      end
    end

    def remove_orphaned_speakers!
      orphaned = orphaned_speakers
      return [] if orphaned.empty?

      orphaned_indices = names.each_with_index.filter_map { |name, index| index if orphaned.include?(name) }

      orphaned_indices.reverse_each { |index| document.root.delete_at(index) }

      orphaned
    end

    def add_missing_speakers
      missing = missing_speakers

      entries = missing.map do |name|
        slug = name.parameterize
        {name: name, slug: slug, github: ""}
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
  end
end
