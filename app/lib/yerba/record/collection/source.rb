# frozen_string_literal: true

module Yerba
  module Record
    class Collection
      # mode
      #   :items  — every item of the sequence at `selector` is a record (videos.yml, speakers.yml, talk.talks)
      #   :single — the whole document is one record (event.yml, series.yml)
      #   :scalar — every scalar item of the sequence is a record (topics.yml)
      #
      class Source
        attr_reader :path, :parsed_selector, :mode, :parent

        def initialize(path: nil, document: nil, selector: "", mode: :items, parent: nil)
          @path = path&.to_s.presence || document&.path
          @document = document
          @parsed_selector = Base.to_selector(selector) || Yerba::Selector.build([])
          @mode = mode
          @parent = parent
        end

        def document
          @document ||= Yerba.parse_file(path) if exist?
        end

        def exist?
          !@document.nil? || (path.present? && File.exist?(path))
        end

        def values
          return nil unless exist?

          parsed_selector.dig(document.values)
        end

        def records(record_class)
          return [] unless exist?

          case mode
          when :single
            [record_class.new(document: document, selector: parsed_selector.empty? ? nil : parsed_selector, parent: parent)]
          else
            items = values

            if items.is_a?(Hash) && parsed_selector.empty?
              [record_class.new(document: document, parent: parent)]
            else
              items_with_nested(record_class, Array(items), parsed_selector, parent)
            end
          end
        end

        def items_with_nested(record_class, items, sequence_selector, parent)
          nested_key = record_class.nested_key

          items.each_with_index.flat_map do |item, index|
            record_selector = sequence_selector.join(index)
            record = record_class.new(document: document, selector: record_selector, parent: parent)
            children = (nested_key && item.is_a?(Hash)) ? Array(item[nested_key]) : []

            [record, *items_with_nested(record_class, children, record_selector.join(nested_key), record)]
          end
        end

        def selector
          @selector ||= parsed_selector.to_s
        end

        def ensure_file!
          return if exist?

          FileUtils.mkdir_p(File.dirname(path))
          Yerba::Document.from([]).save_to!(path)
        end
      end
    end
  end
end
