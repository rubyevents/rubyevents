# frozen_string_literal: true

module Yerba
  module Record
    module Indexing
      extend ActiveSupport::Concern

      class_methods do
        def add_index(field, include: nil)
          index_options[field.to_s] = {include: include}
        end

        def index_options
          @index_options ||= {}
        end

        def find_by(**criteria)
          if criteria.size == 1
            field, value = criteria.first

            return index_on(field)[value] if indexed_field?(field)
          end

          all.find_by(**criteria)
        end

        def indexed_field?(field)
          index_options.key?(field.to_s)
        end

        def index_on(field)
          collection = all

          return collection.index_on(field) if collection.respond_to?(:index_on)

          @indexes ||= {}

          @indexes[field.to_s] ||= collection.each_with_object({}) do |record, index|
            value = record[field.to_s]
            index[value.to_s] = record if value.present?
          end
        end
      end
    end
  end
end
