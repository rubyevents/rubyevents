# frozen_string_literal: true

module Yerba
  module Record
    module Indexing
      extend ActiveSupport::Concern

      class_methods do
        def add_index(field)
          @indexed_fields ||= []
          @indexed_fields << field.to_s
        end

        def find_by(**criteria)
          if criteria.size == 1
            field, value = criteria.first

            if indexed_field?(field.to_s)
              return indexes[field.to_s][value.to_s]
            end
          end

          all.find_by(**criteria)
        end

        def indexed_field?(field)
          @indexed_fields&.include?(field.to_s)
        end

        def indexes
          @indexes ||= build_indexes
        end

        private

        def build_indexes
          result = {}
          collection = all

          (@indexed_fields || []).each do |field|
            if collection.respond_to?(:build_index)
              result[field] = collection.build_index(field)
            else
              index = {}

              collection.each { |record|
                value = record[field]
                index[value.to_s] = record if value
              }

              result[field] = index
            end
          end

          result
        end
      end
    end
  end
end
