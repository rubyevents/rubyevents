# frozen_string_literal: true

module Yerba
  module Record
    Commit = Data.define(:sha, :author, :email, :date, :subject) do
      def short_sha
        sha[0, 9]
      end

      def pr_number
        subject.to_s[/\(#(\d+)\)\z/, 1]&.to_i
      end
    end
  end
end
