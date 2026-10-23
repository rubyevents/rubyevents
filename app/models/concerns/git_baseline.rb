# frozen_string_literal: true

require "open3"

module GitBaseline
  extend ActiveSupport::Concern

  class_methods do
    def baseline_file(relative_path)
      return nil unless baseline_ref

      [relative_path, *renamed_paths(relative_path)].each do |path|
        content, success = git("show", "#{baseline_ref}:#{path}")
        return Yerba.parse(content) if success
      end

      nil
    end

    def renamed_paths(relative_path)
      directory, file = File.split(relative_path)

      [File.basename(directory), *old_event_ids(directory)].uniq.flat_map do |old_id|
        baseline_event_directories.fetch(old_id, []).map { |old_directory| File.join(old_directory, file) }
      end
    end

    def old_event_ids(directory)
      event_file = File.join(directory, "event.yml")
      return [] unless File.exist?(event_file)

      Static::Event.in_file(event_file).first&.old_ids || []
    end

    def baseline_event_directories
      return @baseline_event_directories if defined?(@baseline_event_directories)
      return @baseline_event_directories = {} unless baseline_ref

      output, success = git("ls-tree", "-r", "--name-only", baseline_ref, "--", "data")
      event_files = success ? output.split("\n").grep(%r{\Adata/[^/]+/[^/]+/event\.yml\z}) : []

      @baseline_event_directories = event_files.map { |path| File.dirname(path) }.group_by { |directory| File.basename(directory) }
    end

    def baseline_ref
      return @baseline_ref if defined?(@baseline_ref)

      @baseline_ref = %w[origin/main main].filter_map { |branch|
        merge_base, success = git("merge-base", "HEAD", branch)
        merge_base.strip.presence if success
      }.first
    end

    def changed_paths
      return @changed_paths if defined?(@changed_paths)

      @changed_paths = if baseline_ref
        output, success = git("diff", "--name-only", baseline_ref, "--", "data")

        output.split("\n").to_set if success
      end
    end

    def git(*arguments)
      output, _stderr, status = Open3.capture3("git", *arguments)

      [output, status.success?]
    rescue Errno::ENOENT
      ["", false]
    end

    def warmup
      changed_paths
    end

    def reset!
      remove_instance_variable(:@baseline_ref) if defined?(@baseline_ref)
      remove_instance_variable(:@changed_paths) if defined?(@changed_paths)
      remove_instance_variable(:@baseline_event_directories) if defined?(@baseline_event_directories)
    end
  end

  private

  def baseline
    @baseline ||= self.class.baseline_file(relative_path)
  end

  def relative_path
    @file_path.to_s.sub("#{Rails.root}/", "")
  end

  def changed_since_baseline?
    return true if @baseline

    self.class.changed_paths.nil? || self.class.changed_paths.include?(relative_path)
  end
end
