# frozen_string_literal: true

require "did_you_mean"

module Static
  class Speaker
    module Integrity
      NameCluster = Struct.new(:names, :score, keyword_init: true)

      def names
        pluck(:name)
      end

      def slugs
        pluck(:slug)
      end

      def aliases
        all.flat_map(&:alias_names)
      end

      def known_names
        all.cached(:known_names) { Set.new(names + aliases) }
      end

      def github_handles
        all.cached(:github_handles) { Set.new(all.flat_map(&:all_github_handles).map(&:downcase)) }
      end

      def known_names_downcased
        all.cached(:known_names_downcased) { Set.new(known_names.compact.map { |name| name.strip.downcase }) }
      end

      def known_reference?(name)
        normalized = name.to_s.strip.downcase

        known_names.include?(name) || known_names_downcased.include?(normalized) || github_handles.include?(normalized)
      end

      def all_speaker_references
        all.cached(:all_speaker_references) { inbound_references }
      end

      def all_referenced_names
        all.cached(:all_referenced_names) { Set.new(all_speaker_references.map(&:value)) }
      end

      def missing_speaker_references
        all_speaker_references.reject { |reference| known_reference?(reference.value) }
      end

      def missing_speakers
        missing_speaker_references.map(&:value).uniq.sort
      end

      def orphaned_speakers
        orphaned.map(&:name)
      end

      def remove_orphaned_speakers!
        speakers = orphaned
        return [] if speakers.empty?

        speakers.sort_by(&:index).reverse_each(&:destroy)
        all.reset!

        speakers.map(&:name)
      end

      def add_missing_speakers(references = missing_speaker_references)
        names = references.map(&:value).uniq.sort
        names.each { |name| add(name: name) }

        names
      end

      def duplicate_slugs
        duplicates(:slug)
      end

      def duplicate_githubs
        duplicates(:github)
      end

      def duplicates(field)
        pluck(field).select(&:present?).tally.select { |_, count| count > 1 }
      end

      def same_name_duplicates
        (names + aliases).compact.tally.select { |_, count| count > 1 }
      end

      def reversed_name_duplicates
        name_set = Set.new(names.compact.map(&:downcase))

        names.compact.each_with_object({}) do |name, result|
          next unless name.include?(" ")

          reversed = name.split(" ").reverse.join(" ")

          next if reversed.downcase == name.downcase
          next unless name_set.include?(reversed.downcase)

          key = [name, reversed].sort
          result[key] ||= key
        end.values
      end

      def near_duplicate_names(threshold: 0.85)
        all.cached([:near_duplicate_names, threshold]) do
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
        find_by(name: name)&.social_handle? || false
      end

      private

      def orphaned
        referenced = all_referenced_names
        referenced_downcased = all.cached(:all_referenced_names_downcased) { Set.new(referenced.map { |name| name.strip.downcase }) }

        all.reject do |speaker|
          speaker_names = [speaker.name, *speaker.alias_names].compact

          speaker_names.any? { |name| referenced.include?(name) || referenced_downcased.include?(name.strip.downcase) } ||
            speaker.all_github_handles.any? { |handle| referenced_downcased.include?(handle.downcase) }
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
    end
  end
end
