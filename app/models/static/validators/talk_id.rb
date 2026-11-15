# frozen_string_literal: true

module Static
  module Validators
    class TalkId
      include GitBaseline

      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, document: nil, baseline: nil)
        @file_path = file_path
        @document = document
        @baseline = baseline
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

        map_unexpected_ids do |node, expected|
          actual = node["id"].to_s
          location = node.source_location("id")

          Static::Validators::Error.new(
            %(id "\e[31m#{actual}\e[0m" does not match the expected id "\e[32m#{expected}\e[0m". Run `bin/rails validate:fix` to rename it, rename any thumbnails, and keep the current id as old_id if needed.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end.compact
      end

      def fix
        return unless applicable?

        cued_thumbnails = {}

        changes = map_unexpected_ids do |talk, expected|
          current = talk["id"].to_s

          # Production is seeded from the baseline, so a committed id is the one it knows the talk by
          talk["old_id"] = current if id_in_baseline?(current)
          talk.delete("old_id") if talk["old_id"] == expected

          if talk["video_id"] == current && !watchable_video?(talk)
            talk["video_id"] = expected
          end

          cued_thumbnails[current] = expected if watchable_video?(talk) && talk["start_cue"].present?
          talk["id"] = expected
        end.compact

        return unless changes.any?

        static_talks.save!

        move_cued_thumbnails(cued_thumbnails)

        {changed: changes.size, file_path: @file_path}
      end

      private

      def move_cued_thumbnails(renames)
        directory = File.join(Static::Talk.root, "app/assets/images/thumbnails", event_slug)

        renames.each do |current, expected|
          source = File.join(directory, "#{current}.webp")
          target = File.join(directory, "#{expected}.webp")

          FileUtils.mv(source, target) if File.exist?(source) && !File.exist?(target)
        end
      end

      def map_unexpected_ids
        expected_ids.map do |talk, expected|
          # Strip out title and deduplication
          expected_regex = expected.sub(/-#{event_slug}\z/, "(-#{talk["title"].parameterize})?(-\\d+)?-#{event_slug}\\z")
          yield(talk, expected) unless talk["id"].match(Regexp.new(expected_regex))
        end
      end

      def id_in_baseline?(id)
        baseline_ids.include?(id) || self.class.baseline_talk_ids.include?(id)
      end

      def baseline_ids
        @baseline_ids ||= baseline ? baseline.ids : []
      end

      def baseline
        @baseline ||= begin
          document = self.class.baseline_file(relative_path)
          Static::Talk.in_file(relative_path, document: document) if document
        end
      end

      def static_talks
        @static_talks ||= Static::Talk.in_file(@file_path, document: @document)
      end

      def expected_ids
        @expected_ids ||= talks.each_with_object({}) do |talk, result|
          result[talk] = id_for(talk).to_s
        end
      end

      def talks
        @talks ||= static_talks.to_a
      end

      def event_slug
        @event_slug ||= File.basename(File.dirname(File.expand_path(@file_path)))
      end

      def id_for(talk)
        @ids ||= {}

        @ids[talk] ||= ::Talk::StaticID.new(
          event_slug: event_slug,
          title: talk["title"],
          speakers: talk["speakers"],
          kind: talk["kind"]
        ).generate
      end

      def watchable_video?(talk)
        talk["video_provider"].in?(::Talk::WATCHABLE_PROVIDERS)
      end

      def numbered(talk, id, index)
        index += 1 until available?(talk, candidate = id.sub(/-#{Regexp.escape(event_slug)}\z/, "-#{index}-#{event_slug}"))

        candidate
      end

      def available?(talk, candidate)
        (reservations.fetch(candidate, []) - [talk]).empty?
      end

      def reservations
        @reservations ||= talks.each_with_object({}) do |talk, result|
          [talk["id"], talk["old_id"]].each do |value|
            next if value.blank?

            (result[value] ||= []) << talk
          end
        end
      end
    end
  end
end
