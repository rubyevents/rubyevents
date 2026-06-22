# frozen_string_literal: true

module Yerba
  module Record
    class Collection
      include Enumerable

      attr_reader :document

      def initialize(document:, entry_class: Entry)
        @document = document
        @entry_class = entry_class
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
        each.find { |entry| criteria.all? { |key, value| entry[key] == value } }
      end

      def where(**criteria)
        select { |entry| criteria.all? { |key, value| entry[key] == value } }
      end

      def create(**attributes)
        unless exist?
          dir = File.dirname(document.path)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)

          Yerba::Document.from([]).save_to!(document.path)
          @document = Yerba::Record::Document.new(document.path)
        end

        document.yerba << attributes
        document.save!

        last
      end

      def save!
        document.save!
      end

      def changed?
        document.changed?
      end

      def exist?
        document.exist?
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
