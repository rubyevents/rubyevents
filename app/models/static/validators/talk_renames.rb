# frozen_string_literal: true

require "open3"

module Static
  module Validators
    class TalkRenames
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, baseline: nil, document: nil)
        @file_path = file_path
        @baseline = baseline
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?
        return [] unless changed_since_baseline?

        renamed_errors + disappeared_errors
      end

      def current
        @current ||= Static::VideosFile.wrap(@file_path, @document)
      end

      def renamed_talks
        @renamed_talks ||= missing_ids.each_with_object({}) do |id, result|
          video_id = baseline.find_by(id: id)&.value_at("video_id")
          node = video_id.presence && current.find_by(video_id: video_id)

          result[node] = id if node
        end
      end

      def disappeared_ids
        missing_ids - renamed_talks.values
      end

      def self.baseline_file(relative_path)
        return nil unless baseline_ref

        content, success = git("show", "#{baseline_ref}:#{relative_path}")
        return nil unless success

        Static::VideosFile.parse(content, path: relative_path)
      end

      def self.baseline_ref
        return @baseline_ref if defined?(@baseline_ref)

        @baseline_ref = %w[origin/main main].filter_map { |branch|
          merge_base, success = git("merge-base", "HEAD", branch)
          merge_base.strip.presence if success
        }.first
      end

      def self.changed_paths
        return @changed_paths if defined?(@changed_paths)

        @changed_paths = if baseline_ref
          output, success = git("diff", "--name-only", baseline_ref, "--", "data")

          output.split("\n").select { |path| File.basename(path) == "videos.yml" }.to_set if success
        end
      end

      def self.git(*arguments)
        output, _stderr, status = Open3.capture3("git", *arguments)

        [output, status.success?]
      rescue Errno::ENOENT
        ["", false]
      end

      def self.warmup
        changed_paths
      end

      def self.reset!
        remove_instance_variable(:@baseline_ref) if defined?(@baseline_ref)
        remove_instance_variable(:@changed_paths) if defined?(@changed_paths)
      end

      private

      def changed_since_baseline?
        return true if @baseline

        self.class.changed_paths.nil? || self.class.changed_paths.include?(relative_path)
      end

      def baseline
        @baseline ||= self.class.baseline_file(relative_path)
      end

      def missing_ids
        return [] if baseline.nil?

        baseline.ids - current.ids - current.old_ids
      end

      def renamed_errors
        renamed_talks.map do |node, previous_id|
          location = node["id"]&.location

          Static::Validators::Error.new(
            %(id "#{node.value_at("id")}" was renamed from "#{previous_id}", but the previous id wasn't kept. Production still knows this talk as "#{previous_id}", so it needs `old_id: "#{previous_id}"` to migrate its record on the next seed. Run `bin/rails talk_ids:backfill_old_ids` to write it for you.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def disappeared_errors
        disappeared_ids.map do |id|
          Static::Validators::Error.new(
            %(id "#{id}" disappeared from this file without being kept as an old_id. If the talk was renamed, please add `old_id: "#{id}"` to the renamed entry so its production record can be migrated on the next seed. If the talk was removed on purpose, this is fine.),
            file_path: @file_path,
            line: 1
          )
        end
      end

      def relative_path
        @file_path.to_s.sub("#{Rails.root}/", "")
      end
    end
  end
end
