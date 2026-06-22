# frozen_string_literal: true

module Yerba
  module Record
    module Querying
      extend ActiveSupport::Concern

      class WhereChain
        def initialize(collection)
          @collection = collection
        end

        def not(**criteria)
          records = @collection.reject do |record|
            criteria.any? { |key, value| record[key.to_s] == value }
          end

          RecordCollection.new(records)
        end
      end

      class_methods do
        attr_writer :path, :glob, :base_path, :flatten, :scalar_field

        def path = @path
        def glob = @glob
        def base_path = @base_path || superclass.try(:base_path)
        def flatten = @flatten || false
        def scalar_field = @scalar_field

        def all
          @all ||= load_all
        end

        delegate :count, :first, :last, :empty?, :each, :pluck, to: :all

        def where(**criteria)
          if criteria.empty?
            WhereChain.new(all)
          else
            all.where(**criteria)
          end
        end

        def unload!
          @all = nil
          @indexes = nil
        end

        private

        def load_all
          if glob
            load_from_glob
          elsif path
            load_from_file
          else
            raise "Set self.path or self.glob on #{name}"
          end
        end

        def load_from_glob
          resolved_glob = base_path ? File.join(base_path, glob) : glob

          if flatten
            load_from_glob_flattened(resolved_glob)
          else
            load_from_glob_single(resolved_glob)
          end
        end

        def load_from_glob_single(resolved_glob)
          records = Dir.glob(resolved_glob).sort.map do |absolute_path|
            document = Yerba::Record::Document.new(absolute_path)
            new(document: document)
          end

          RecordCollection.new(records)
        end

        def load_from_glob_flattened(resolved_glob)
          records = Dir.glob(resolved_glob).sort.flat_map do |absolute_path|
            document = Yerba::Record::Document.new(absolute_path)
            data = document.yerba.to_a
            items = data.is_a?(Array) ? data : [data]

            items.each_with_index.map do |_item, index|
              new(document: document, index: index)
            end
          end

          RecordCollection.new(records)
        end

        def load_from_file
          resolved_path = base_path ? File.join(base_path, path) : path
          document = Yerba::Record::Document.new(resolved_path)

          if scalar_field
            records = document.root.each_with_index.map do |_node, index|
              new(document: document, index: index)
            end

            RecordCollection.new(records)
          else
            LazyFileCollection.new(document: document, record_class: self)
          end
        end
      end
    end
  end
end
