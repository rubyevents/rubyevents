# frozen_string_literal: true

require "did_you_mean"

module Static
  class SpeakersFile
    attr_reader :document

    NameCluster = Struct.new(:names, :score, keyword_init: true)

    SOCIAL_HANDLE_FIELDS = %w[github twitter mastodon bluesky linkedin speakerdeck].freeze

    SPEAKERS_PATH = "data/speakers.yml"
    VIDEOS_GLOB = "data/**/videos.yml"
    INVOLVEMENTS_GLOB = "data/**/involvements.yml"

    VIDEO_SPEAKER_SELECTORS = [
      "[].speakers[]",
      "[].alternative_recordings[].speakers[]",
      "[].talks[].speakers[]",
      "[].talks[].alternative_recordings[].speakers[]"
    ].freeze

    class StaleFileError < StandardError; end

    def initialize(path = Rails.root.join(SPEAKERS_PATH).to_s, document: nil)
      @path = path
      @loaded_mtime = File.mtime(path)
      @document = document || Yerba.parse_file(path)
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
      (names + aliases).compact.tally.select { |_, count| count > 1 }
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

    def near_duplicate_names(threshold: 0.85)
      (@near_duplicate_names ||= {})[threshold] ||= begin
        entries = names.compact.reject(&:empty?)
        pairs = similar_name_pairs(entries, threshold)

        similar_name_clusters(pairs, entries.size).map do |indices|
          best = indices.combination(2).filter_map { |i, j| pairs[[i, j]] }.max
          NameCluster.new(names: indices.map { |i| entries[i] }.sort, score: best)
        end.sort_by { |cluster| -cluster.score }
      end
    end

    def name_similarity(a, b)
      a = a.downcase
      b = b.downcase
      return 1.0 if a == b

      max = [a.length, b.length].max
      return 1.0 if max.zero?

      1.0 - (DidYouMean::Levenshtein.distance(a, b).to_f / max)
    end

    def social_handle?(name)
      social_handles.fetch(name, false)
    end

    def save!
      if File.mtime(@path) != @loaded_mtime
        raise StaleFileError, "#{@path} was modified externally since it was loaded"
      end

      document.sort(by: :name)
      document.save!(apply: true)

      @loaded_mtime = File.mtime(@path)

      reset_cache
    end

    def changed?
      document.changed?
    end

    private

    def reset_cache
      @known_names = nil
      @indexes = nil
      @all_speaker_references = nil
      @all_referenced_names = nil
      @near_duplicate_names = nil
      @social_handles = nil
    end

    def social_handles
      @social_handles ||= document.value_at("").to_h do |entry|
        [entry["name"], SOCIAL_HANDLE_FIELDS.any? { |field| entry[field].to_s.strip.present? }]
      end
    end

    def similar_name_pairs(entries, threshold)
      normalized = entries.map(&:downcase)
      blocks = Hash.new { |hash, key| hash[key] = [] }
      pairs = {}

      entries.each_with_index do |name, index|
        name_blocking_keys(name).each { |key| blocks[key] << index }
      end

      blocks.each_value do |indices|
        indices.combination(2) do |i, j|
          a, b = normalized[i], normalized[j]
          next if a == b

          max = [a.length, b.length].max
          distance = bounded_levenshtein(a, b, ((1.0 - threshold) * max).floor)
          pairs[[i, j]] = 1.0 - (distance.to_f / max) if distance
        end
      end
      pairs
    end

    def name_blocking_keys(name)
      compact = name.downcase.gsub(/[^a-z0-9]/, "")
      return [] if compact.empty?

      ["f:#{compact[0, 3]}", "l:#{compact[-4..] || compact}"]
    end

    def bounded_levenshtein(a, b, max_distance)
      return nil if (a.length - b.length).abs > max_distance

      previous = (0..a.length).to_a

      (1..b.length).each do |j|
        current = Array.new(a.length + 1)
        current[0] = j
        b_char = b[j - 1]
        row_min = j

        (1..a.length).each do |i|
          cost = (a[i - 1] == b_char) ? 0 : 1
          value = previous[i] + 1
          left = current[i - 1] + 1
          diagonal = previous[i - 1] + cost
          value = left if left < value
          value = diagonal if diagonal < value
          current[i] = value
          row_min = value if value < row_min
        end

        return nil if row_min > max_distance
        previous = current
      end

      (previous[a.length] <= max_distance) ? previous[a.length] : nil
    end

    def similar_name_clusters(pairs, count)
      parent = Array.new(count) { |i| i }
      root = lambda do |x|
        x = parent[x] while parent[x] != x

        x
      end

      pairs.each_key { |i, j| parent[root.call(i)] = root.call(j) }

      groups = Hash.new { |hash, key| hash[key] = [] }
      pairs.each_key { |i, j| [i, j].each { |x| groups[root.call(x)] << x } }

      groups.values.map(&:uniq)
    end

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
