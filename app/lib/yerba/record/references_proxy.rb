# frozen_string_literal: true

module Yerba
  module Record
    class ReferencesProxy
      include Enumerable

      attr_reader :resolver

      # raw      — the Yerba::Sequence (or Array) of strings from the source document, or a callable returning it
      # values   — optional plain Array of the current values, used for reads so the CST isn't touched
      # resolver — a callable that takes a name and returns an Entry or nil
      # creator  — a callable that takes a name and creates + returns an Entry
      # entry    — the parent Entry (for save! delegation)
      def initialize(raw:, resolver:, values: nil, creator: nil, entry: nil)
        @raw = raw
        @values = values
        @resolver = resolver
        @creator = creator
        @entry = entry
      end

      def each(&block)
        return enum_for(:each) unless block_given?

        values.each do |value|
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
        reset_entry_cache!
        resolved || name
      end

      def delete(name)
        index = values.index(name)

        if index
          raw.delete_at(index)
          reset_entry_cache!
        end

        self
      end

      def include?(name)
        values.include?(name)
      end

      def count
        values.length
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
        values.map(&:to_s)
      end

      def raw
        @raw = @raw.call if @raw.respond_to?(:call)
        @raw
      end

      def inspect
        "#<#{self.class.name} #{names.inspect}>"
      end

      private

      def values
        @values || Array(raw)
      end

      def reset_entry_cache!
        @values = nil
        @entry.document&.reset_values! if @entry.respond_to?(:document)
        @entry.reset_attributes_cache! if @entry.respond_to?(:reset_attributes_cache!)
      end
    end
  end
end
