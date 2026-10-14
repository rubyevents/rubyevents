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
          all.find_by(**criteria)
        end

        def indexed_field?(field)
          index_options.key?(field.to_s)
        end

        def index_on(field)
          all.index_on(field)
        end
      end
    end
  end
end
