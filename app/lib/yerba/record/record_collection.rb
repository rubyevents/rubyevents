# frozen_string_literal: true

module Yerba
  module Record
    class RecordCollection
      include Enumerable

      def initialize(records)
        @records = records
      end

      def each(&block)
        @records.each(&block)
      end

      def [](index)
        @records[index]
      end

      def first = @records.first
      def last = @records.last
      def count = @records.count
      alias_method :size, :count
      alias_method :length, :count
      def empty? = @records.empty?

      def find_by(**criteria)
        @records.find { |record| criteria.all? { |key, value| record[key.to_s] == value } }
      end

      def where(**criteria)
        @records.select { |record| criteria.all? { |key, value| record[key.to_s] == value } }
      end

      def pluck(field)
        @records.map { |record| record.send(field) }
      end

      def to_a = @records.dup
      def select(&block) = @records.select(&block)
      def reject(&block) = @records.reject(&block)
      def map(&block) = @records.map(&block)
      def flat_map(&block) = @records.flat_map(&block)
      def sort_by(&block) = @records.sort_by(&block)
      def group_by(&block) = @records.group_by(&block)
      def index_by(&block) = @records.index_by(&block)
    end
  end
end
