# frozen_string_literal: true

module Yerba
  module Record
    # Git history of the lines a record spans, read from `git blame` of its file on disk:
    #
    #   talk.commit                         # the last commit that changed one of its lines
    #   talk.created_at                     # when the oldest of its lines was committed
    #   talk.commit_for(:video_provider)    # the last commit that changed that field
    #   Static::Talk.where(created_at: Date.new(2026, 9, 1)..)
    #
    # Records parsed from a string have no file to blame, and lines that aren't committed yet are skipped.
    #
    module History
      def commits
        commits_for(source_location)
      end

      def commit
        commits.last
      end

      def first_commit
        commits.first
      end

      def created_at
        first_commit&.date
      end

      def updated_at
        commit&.date
      end

      def commit_for(key)
        commits_for(source_location(key)).last
      end

      private

      def commits_for(location)
        blame = location && document&.path && Blame.for(document.path)
        return [] unless blame

        blame.commits_in(location.start_line..location.end_line).sort_by(&:date)
      end
    end
  end
end
