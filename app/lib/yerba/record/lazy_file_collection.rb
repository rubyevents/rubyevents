# frozen_string_literal: true

module Yerba
  module Record
    class LazyFileCollection
      include Enumerable

      attr_reader :document

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
        return find { |record| Criteria.match?(record, criteria) } unless Criteria.plain?(criteria)

        result = @document.find_by(**criteria)
        return nil unless result

        index = index_from_selector(result.selector)
        index ? record_at(index) : nil
      end

      def where(**criteria)
        return select { |record| Criteria.match?(record, criteria) } unless Criteria.plain?(criteria)

        @document.where(**criteria).filter_map do |result|
          index = index_from_selector(result.selector)
          record_at(index) if index
        end
      end

      def pluck(*fields)
        return @document.pluck(fields.first.to_sym) if fields.one?

        map { |record| fields.map { |field| record.public_send(field) } }
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

      def index_on(field)
        @indexes ||= {}
        @indexes[field.to_s] ||= build_index(field)
      end

      def reset!
        @indexes = nil
        @cached_count = nil
      end

      private

      def record_at(index)
        return nil if index.nil? || index.negative? || index >= cached_count

        @record_class.new(document: @document, index: index)
      end

      def build_index(field)
        field = field.to_s
        list_field, item_field = included_selector(field)
        positions = {}
        included_positions = {}

        Array(@document.values).each_with_index do |entry, position|
          next unless entry.is_a?(Hash)

          value = entry[field]
          positions[value.to_s] = position if value.present?

          next unless list_field

          Array(entry[list_field]).each do |item|
            included = item_field ? (item[item_field] if item.is_a?(Hash)) : item
            included_positions[included.to_s] ||= position if included.present?
          end
        end

        LazyIndex.new(positions, included_positions, collection: self)
      end

      def included_selector(field)
        selector = @record_class.try(:index_options)&.dig(field, :include)
        return unless selector

        list_field, item_field = selector.to_s.split("[]", 2)

        [list_field, item_field.delete_prefix(".").presence]
      end

      def cached_count
        @cached_count ||= @document.root.length
      end

      def index_from_selector(selector)
        selector[/\[(\d+)\]/, 1]&.to_i
      end
    end

    class LazyIndex
      attr_reader :positions, :included_positions

      def initialize(positions, included_positions = {}, collection:)
        @positions = positions
        @included_positions = included_positions
        @collection = collection
      end

      def [](key)
        position = position(key)
        position ? @collection.send(:record_at, position) : nil
      end

      def position(key)
        @positions[key.to_s] || @included_positions[key.to_s]
      end

      def key?(key)
        !position(key).nil?
      end

      def keys
        (@positions.keys + @included_positions.keys).uniq
      end

      def size
        keys.size
      end
    end
  end
end
