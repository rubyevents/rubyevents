# frozen_string_literal: true

module Yerba
  module Record
    class Collection
      include Enumerable

      attr_reader :path

      def initialize(path: nil, document: nil, entry_class: Entry)
        @path = (path || document&.path).to_s
        @document = document
        @entry_class = entry_class
      end

      def document
        @document ||= Yerba.parse_file(path) if exist?
      end

      def each(&block)
        return enum_for(:each) unless block_given?
        return unless exist?

        document.root.each_with_index do |_node, index|
          yield entry_at(index)
        end
      end

      def [](index)
        return nil unless exist?

        index = count + index if index.negative?
        entry_at(index)
      end

      def first
        return nil unless exist?

        entry_at(0)
      end

      def last
        return nil unless exist?

        entry_at(count - 1)
      end

      def count
        return 0 unless exist?

        document.root.length
      end
      alias_method :size, :count
      alias_method :length, :count

      def empty?
        !exist? || count.zero?
      end

      def find_by(**criteria)
        each.find { |entry| Criteria.match?(entry, criteria) }
      end

      def where(**criteria)
        select { |entry| Criteria.match?(entry, criteria) }
      end

      def create(**attributes)
        unless exist?
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)

          Yerba::Document.from([]).save_to!(path)
        end

        document << attributes
        document.save!(apply: true)

        last
      end

      def save!
        document.save!(apply: true)
      end

      def changed?
        document.changed?
      end

      def exist?
        !@document.nil? || File.exist?(path)
      end

      def pluck(field)
        map { |entry| entry[field] }
      end

      private

      def entry_at(index)
        return nil if index.nil? || index.negative? || index >= count

        @entry_class.new(document: document, index: index)
      end
    end
  end
end
