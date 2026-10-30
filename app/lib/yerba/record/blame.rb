# frozen_string_literal: true

require "open3"

module Yerba
  module Record
    # `git blame` of a file on disk, parsed once and cached until the file is modified.
    #
    class Blame
      UNCOMMITTED_SHA = "0" * 40
      HEADER = /\A(\h{40}) \d+ (\d+)/

      def self.for(path)
        path = File.expand_path(path.to_s)
        return unless File.exist?(path)

        mtime = File.mtime(path)
        cached = cache[path]

        (cached&.mtime == mtime) ? cached : cache[path] = new(path, mtime: mtime)
      end

      def self.cache
        @cache ||= {}
      end

      def self.reset!
        @cache = {}
      end

      attr_reader :path, :mtime

      def initialize(path, mtime:)
        @path = path
        @mtime = mtime
        @lines = {}
        @commits = {}

        parse(blame)
      end

      def commit_at(line)
        @commits[@lines[line]]
      end

      def commits_in(lines)
        lines.filter_map { |line| commit_at(line) }.uniq
      end

      private

      def blame
        output, _stderr, status = Open3.capture3("git", "blame", "-w", "--porcelain", "--", File.basename(path), chdir: File.dirname(path))

        status.success? ? output : ""
      rescue Errno::ENOENT
        ""
      end

      def parse(output)
        fields = Hash.new { |hash, sha| hash[sha] = {} }
        sha = line = nil

        output.each_line(chomp: true) do |row|
          if row.start_with?("\t")
            @lines[line] = sha
            @commits[sha] ||= build_commit(sha, fields[sha]) unless sha == UNCOMMITTED_SHA
          elsif (match = row.match(HEADER))
            sha = match[1]
            line = match[2].to_i
          else
            key, value = row.split(" ", 2)
            fields[sha][key] = value
          end
        end
      end

      def build_commit(sha, fields)
        Commit.new(
          sha: sha,
          author: fields["author"],
          email: fields["author-mail"].to_s.delete("<>"),
          date: Time.zone.at(fields["committer-time"].to_i),
          subject: fields["summary"]
        )
      end
    end
  end
end
