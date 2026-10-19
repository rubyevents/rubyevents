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
            %(id "#{actual}" does not match the expected id "#{expected}". Talk ids should be "firstname-lastname-#{event_slug}", with the kind added on duplicates, the kind alone for talks without one or two speakers, and the title in slug form as a last resort. Run `bin/rails validate:fix` to rename it and keep the current id as old_id.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end.compact
      end

      def fix
        return unless applicable?

        changes = map_unexpected_ids do |node, expected|
          current = node["id"].to_s
          node["old_id"] = current if node["old_id"].blank? && id_in_baseline?(current)
          node.delete("old_id") if node["old_id"] == expected
          if node["video_id"] == current && !watchable_video?(node)
            node["video_id"] = expected
          end
          rename_thumbnails(current, expected)
          node["id"] = expected
        end.compact
        return unless changes.any?
        videos_file.save!
        {changed: changes.size, file_path: @file_path}
      end

      private

      def map_unexpected_ids
        expected_ids.map do |node, expected|
          actual = node["id"].to_s
          yield(node, expected) if actual != expected
        end
      end

      def id_in_baseline?(id)
        baseline_ids.include?(id)
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

      def videos_file
        @videos_file ||= Static::Talk.in_file(@file_path, document: @document)
      end

      def expected_ids
        return {} if meetup_event?

        @expected_ids ||= nodes.group_by { |node| speaker_id(node) }.each_with_object({}) do |(id, group), result|
          next if id.blank?
          next result[group.first] = id if group.one? && available?(group.first, id)

          group.group_by { |node| kind_id(node) }.each do |with_kind, kind_group|
            next if with_kind.blank?
            next result[kind_group.first] = with_kind if kind_group.one? && available?(kind_group.first, with_kind)

            kind_group.group_by { |node| title_id(node) }.each do |with_title, title_group|
              next if with_title.blank?

              if title_group.one? && available?(title_group.first, with_title)
                result[title_group.first] = with_title
              else
                title_group.each_with_index do |node, index|
                  result[node] = numbered(node, with_title, index + 1)
                end
              end
            end
          end
        end
      end

      def nodes
        @nodes ||= videos_file.to_a
      end

      def event_slug
        @event_slug ||= File.basename(File.dirname(File.expand_path(@file_path)))
      end

      def meetup_event?
        event_file = File.join(File.dirname(File.expand_path(@file_path)), "event.yml")
        return false unless File.exist?(event_file)

        Static::Event.in_file(event_file).first["kind"] == "meetup"
      end

      def id_for(node)
        @ids ||= {}

        @ids[node] ||= ::Talk::StaticID.new(
          event_slug: event_slug,
          title: node["title"],
          speakers: node["speakers"],
          kind: node["kind"]
        )
      end

      def speaker_id(node)
        id_for(node).speaker_id
      end

      def kind_id(node)
        id_for(node).kind_id
      end

      def title_id(node)
        id_for(node).title_id
      end

      def watchable_video?(node)
        node["video_provider"].in?(::Talk::WATCHABLE_PROVIDERS)
      end

      def rename_thumbnails(from, to)
        event_thumbnails = Rails.root.join("app/assets/images/thumbnails", event_slug)

        Dir.glob(event_thumbnails.join("**/#{from}.webp")).each do |thumbnail|
          renamed_thumbnail = File.join(File.dirname(thumbnail), "#{to}.webp")
          FileUtils.mv(thumbnail, renamed_thumbnail) unless File.exist?(renamed_thumbnail)
        end

        directory = event_thumbnails.join(from)
        renamed_directory = event_thumbnails.join(to)
        FileUtils.mv(directory, renamed_directory) if Dir.exist?(directory) && !Dir.exist?(renamed_directory)
      end

      def numbered(node, id, index)
        index += 1 until available?(node, candidate = id.sub(/-#{Regexp.escape(event_slug)}\z/, "-#{index}-#{event_slug}"))

        candidate
      end

      def available?(node, candidate)
        (reservations.fetch(candidate, []) - [node]).empty?
      end

      def reservations
        @reservations ||= nodes.each_with_object({}) do |node, result|
          [node["id"], node["old_id"]].each do |value|
            next if value.blank?

            (result[value] ||= []) << node
          end
        end
      end
    end
  end
end
