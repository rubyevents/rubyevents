# frozen_string_literal: true

module Static
  module Validators
    # Makes sure a talk doesn't list the same speaker twice. Names are resolved
    # through data/speakers.yml, so a speaker's name and one of their aliases
    # count as the same speaker, just like the import does. Otherwise the import
    # fails to save the talk, because a user can only be linked to it once.
    #
    class UniqueTalkSpeakers
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        Static::Talk.in_file(@file_path, document: @document).pairs.flat_map do |video, nested|
          talk_errors(video) + nested.flat_map { |talk| talk_errors(talk) }
        end
      end

      def self.speaker_names
        @speaker_names ||= Static::Speaker.all.each_with_object({}) do |speaker, names|
          names[speaker["name"].to_s.strip] = speaker["name"].to_s.strip

          Array(speaker["aliases"]).each do |alias_data|
            names[alias_data["name"].to_s.strip] ||= speaker["name"].to_s.strip if alias_data.is_a?(Hash)
          end
        end
      end

      def self.warmup
        speaker_names
      end

      def self.reset!
        @speaker_names = nil
      end

      private

      def talk_errors(node)
        names = Array(node["speakers"]).map { |name| name.to_s.strip }
        indexes = names.each_index.reject { |index| names[index].empty? }
        duplicates = indexes.group_by { |index| self.class.speaker_names.fetch(names[index], names[index]) }.select { |_, group| group.size > 1 }
        return [] if duplicates.empty?

        duplicates.map do |speaker, group|
          listed = group.map { |index| names[index] }.uniq.map { |name| "\"#{name}\"" }.join(", ")
          location = speaker_location(node, group.second) || node.source_location("speakers")

          Static::Validators::Error.new(
            "speaker \"#{speaker}\" is listed #{group.size} times (as #{listed}). Remove the duplicate or point it at the right speaker in data/speakers.yml.",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def speaker_location(node, index)
        speakers = node.node["speakers"] if node.node.respond_to?(:[])
        item = speakers[index] if speakers.respond_to?(:[])

        item.location if item.respond_to?(:location)
      end
    end
  end
end
