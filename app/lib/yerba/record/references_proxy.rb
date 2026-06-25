# frozen_string_literal: true

module Yerba
  module Record
    class ReferencesProxy
      include Enumerable

      attr_reader :raw, :resolver

      # raw      — the Yerba::Sequence (or Array) of strings from the source document
      # resolver — a callable that takes a name and returns an Entry or nil
      # creator  — a callable that takes a name and creates + returns an Entry
      # entry    — the parent Entry (for save! delegation)
      def initialize(raw:, resolver:, creator: nil, entry: nil)
        @raw = raw
        @resolver = resolver
        @creator = creator
        @entry = entry
      end

      def each(&block)
        return enum_for(:each) unless block_given?

        Array(raw).each do |value|
          resolved = resolver.call(value)
          yield resolved || value
        end
      end

      def <<(name)
        resolved = resolver.call(name)

        if resolved.nil? && @creator
          resolved = @creator.call(name)
        end

        raw << name
        resolved || name
      end

      def delete(name)
        index = Array(raw).index(name)
        raw.delete_at(index) if index
        self
      end

      def include?(name)
        Array(raw).include?(name)
      end

      def count
        Array(raw).length
      end
      alias_method :size, :count
      alias_method :length, :count

      def empty?
        count.zero?
      end

      def to_a
        map { |entry| entry }
      end

      def names
        Array(raw).map(&:to_s)
      end

      def inspect
        "#<#{self.class.name} #{names.inspect}>"
      end
    end
  end
end
