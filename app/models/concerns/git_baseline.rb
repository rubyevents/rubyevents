# frozen_string_literal: true

require "open3"

module GitBaseline
  extend ActiveSupport::Concern

  class_methods do
    def baseline_file(relative_path)
      return nil unless baseline_ref

      content, success = git("show", "#{baseline_ref}:#{relative_path}")
      return nil unless success

      Yerba.parse(content)
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
