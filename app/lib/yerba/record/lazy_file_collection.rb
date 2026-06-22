# frozen_string_literal: true

module Yerba
  module Record
    class LazyFileCollection
      include Enumerable

      def initialize(document:, record_class:)
        @document = document
        @record_class = record_class
      end

      def each
        return enum_for(:each) unless block_given?

        @document.root.each_with_index do |_node, index|
          yield record_at(index)
        end
      end

      def [](index)
        index = count + index if index.negative?
        record_at(index)
      end

      def first = record_at(0)
      def last = record_at(count - 1)
      def count = cached_count
      alias_method :size, :count
      alias_method :length, :count
      def empty? = count.zero?

      def find_by(**criteria)
        result = @document.yerba.find_by(**criteria)
        return nil unless result

        index = index_from_selector(result.selector)
        index ? record_at(index) : nil
      end

      def where(**criteria)
        @document.yerba.where(**criteria).filter_map do |result|
          index = index_from_selector(result.selector)
          record_at(index) if index
        end
      end

      def pluck(field)
        @document.yerba.pluck(field.to_sym)
      end

      def select
        results = []
        each { |record| results << record if yield(record) }
        results
      end

      def reject
        results = []
        each { |record| results << record unless yield(record) }
        results
      end

      def map
        results = []
        each { |record| results << yield(record) }
        results
      end

      def flat_map
        results = []
        each { |record| results.concat(Array(yield(record))) }
        results
      end

      def index_by
        result = {}
        each { |record| result[yield(record)] = record }
        result
      end

      def to_a
        each.to_a
      end

      def build_index(field)
        values = @document.yerba.pluck(field.to_sym)
        raw_index = {}

        values.each_with_index do |value, position|
          raw_index[value.to_s] = position if value
        end

        LazyIndex.new(raw_index, collection: self)
      end

      private

      def record_at(index)
        return nil if index.nil? || index.negative? || index >= cached_count

        @record_class.new(document: @document, index: index)
      end

      def cached_count
        @cached_count ||= @document.root.length
      end

      def index_from_selector(selector)
        selector[/\[(\d+)\]/, 1]&.to_i
      end
    end

    class LazyIndex
      def initialize(raw_index, collection:)
        @raw_index = raw_index
        @collection = collection
      end

      def [](key)
        position = @raw_index[key.to_s]
        position ? @collection.send(:record_at, position) : nil
      end

      def key?(key)
        @raw_index.key?(key.to_s)
      end

      def keys
        @raw_index.keys
      end

      def size
        @raw_index.size
      end
    end
  end
end
