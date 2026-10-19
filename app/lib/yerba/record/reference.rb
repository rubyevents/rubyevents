# frozen_string_literal: true

module Yerba
  module Record
    Reference = Data.define(:value, :record, :selector) do
      def file_path
        record.file_path
      end

      def line
        record.source_line(selector)
      end

      def full_selector
        [record.selector.presence, selector].compact.join(".")
      end
    end
  end
end
