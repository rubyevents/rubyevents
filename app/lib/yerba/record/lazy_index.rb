# frozen_string_literal: true

module Yerba
  module Record
    class LazyIndex
      attr_reader :positions, :included_positions

      def initialize(positions, included_positions = {}, collection:)
        @positions = positions
        @included_positions = included_positions
        @collection = collection
      end

      def [](key)
        position = position(key)

        position ? @collection[position] : nil
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
