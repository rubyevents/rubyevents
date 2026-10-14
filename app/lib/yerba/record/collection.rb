# frozen_string_literal: true

module Yerba
  module Record
    class Collection
      include Enumerable

      class WhereChain
        def initialize(collection)
          @collection = collection
        end

        def not(**criteria)
          @collection.subset(@collection.reject { |record| criteria.any? { |key, value| Criteria.value_matches?(Criteria.value_for(record, key), value) } })
        end

        def missing(*associations)
          @collection.subset(@collection.select { |record| associations.all? { |name| Criteria.value_for(record, name).nil? } })
        end

        def associated(*associations)
          @collection.subset(@collection.select { |record| associations.all? { |name| !Criteria.value_for(record, name).nil? } })
        end
      end

      attr_reader :record_class, :sources

      def initialize(record_class: Base, sources: nil, records: nil, path: nil, document: nil, selector: "", mode: :items, parent: nil)
        @record_class = record_class
        @sources = sources || [Source.new(path: path, document: document, selector: selector, mode: mode, parent: parent)]
        @filtered_records = records
      end

      def each(&block)
        return enum_for(:each) unless block_given?

        records.each(&block)
      end

      def [](position)
        records[position]
      end

      def first(...) = records.first(...)
      def last(...) = records.last(...)
      def count(...) = records.count(...)
      def size = records.size
      alias_method :length, :size
      def empty? = records.empty?
      def to_a = records.dup

      def find_by(**criteria)
        if criteria.size == 1 && !filtered?
          field, value = criteria.first

          return index_on(field)[value] if record_class.indexed_field?(field) && Criteria.plain?(criteria)
        end

        records.find { |record| Criteria.match?(record, criteria) }
      end

      def where(**criteria, &block)
        return WhereChain.new(self) if criteria.empty? && !block

        subset(records.select { |record| (criteria.empty? || Criteria.match?(record, criteria)) && (!block || block.call(record)) })
      end

      def pluck(*fields)
        if fields.one?
          records.map { |record| record.public_send(fields.first) }
        else
          records.map { |record| fields.map { |field| record.public_send(field) } }
        end
      end

      def index_on(field)
        @indexes ||= {}
        @indexes[field.to_s] ||= build_index(field.to_s)
      end

      def subset(records)
        self.class.new(record_class: record_class, sources: sources, records: records.to_a)
      end

      def filtered?
        !@filtered_records.nil?
      end

      def documents
        if filtered?
          @filtered_records.map(&:document).compact.uniq(&:object_id)
        else
          sources.filter_map(&:document)
        end
      end

      def files
        if filtered?
          @filtered_records.group_by { |record| record.document.object_id }.values.map { |records| subset(records) }
        else
          sources.map { |source| self.class.new(record_class: record_class, sources: [source]) }
        end
      end

      def single_file?
        sources.one?
      end

      def source
        raise ArgumentError, "#{self.class.name} spans #{sources.size} files, use #files" unless single_file?

        sources.first
      end

      def document = source.document
      def path = source.path
      def selector = source.selector
      def parent = source.parent

      def relative_path
        return nil if path.blank?

        path.to_s.delete_prefix("#{Rails.root}/")
      end

      def exist?
        sources.any?(&:exist?)
      end

      def changed?
        documents.any?(&:changed?)
      end

      def save!
        changed = documents.select(&:changed?)
        changed.each { |document| document.sort("", by: record_class.order_by.to_s) } if record_class.try(:order_by)
        changed.each { |document| document.save!(apply: true) }

        written!
      end

      def reset!
        @records = nil
        @indexes = nil
        @cache = nil
      end

      # Memoizes a value for this collection until it changes (see #reset!)
      def cached(key)
        @cache ||= {}
        return @cache[key] if @cache.key?(key)

        @cache[key] = yield
      end

      def build(attributes = nil, at: nil, before: nil, after: nil, **kwargs)
        raise ArgumentError, "Cannot build records in a filtered collection" if filtered?

        attributes = (attributes || {}).merge(kwargs).deep_stringify_keys
        position = insert_position(at: at, before: before, after: after)

        source.ensure_file!

        if source.values.nil? && parent && source.parsed_selector.segments.last.is_a?(String)
          parent[source.parsed_selector.segments.last] = [attributes]
        elsif position
          document.insert_object(selector, attributes, at: position)
        else
          document.insert_object(selector, attributes)
        end

        reset!
        parent&.reset_attributes_cache!

        attributes["id"] ? find_by(id: attributes["id"]) : items[position || (items.size - 1)]
      end

      def create(attributes = nil, at: nil, before: nil, after: nil, **kwargs)
        record = build(attributes, at: at, before: before, after: after, **kwargs)
        id = record&.id

        save!

        id ? find_by(id: id) : record
      end

      def destroy(record_or_id)
        record = resolve(record_or_id)
        raise ArgumentError, "No record #{record_or_id.inspect} in #{relative_path || "collection"}" unless record

        record.destroy

        written!
      end

      def reorder(ids)
        raise ArgumentError, "Cannot reorder a filtered collection" if filtered?

        ids = ids.map(&:to_s)
        current = items.map(&:id)

        unless current.none?(&:nil?) && ids.sort == current.map(&:to_s).sort
          raise ArgumentError, "reorder needs exactly the current ids (#{current.inspect}), got #{ids.inspect}"
        end

        document.sort(selector, by: ".id", order: ids)

        save!
      end

      def move(record_or_id, to: nil, before: nil, after: nil)
        id = resolve(record_or_id)&.id or raise ArgumentError, "No record #{record_or_id.inspect}"
        ids = items.map(&:id)
        ids.delete(id)

        position = to || (before && ids.index(resolve_id(before))) || (after && ids.index(resolve_id(after))&.succ)
        raise ArgumentError, "move needs one of to:, before: or after:" if position.nil?

        ids.insert(position, id)
        reorder(ids)
      end

      def inspect
        paths = filtered? ? documents.map(&:path) : sources.map(&:path)
        location = (paths.size == 1) ? (paths.first&.delete_prefix("#{Rails.root}/") || "(parsed)") : "#{paths.size} #{"file".pluralize(paths.size)}"

        class_name = instance_of?(Collection) ? "Yerba::Record::Collection[#{record_class.name}]" : self.class.name

        "#<#{class_name} #{location}, #{count} #{"record".pluralize(count)}>"
      end

      private

      # Like an ActiveRecord relation, a collection runs the model's own class methods (and scopes) over itself
      def method_missing(name, ...)
        return super unless model_method?(name)

        record_class.scoping(self) { record_class.public_send(name, ...) }
      end

      def respond_to_missing?(name, include_private = false)
        model_method?(name) || super
      end

      def model_method?(name)
        record_class.respond_to?(name) && !Base.respond_to?(name)
      end

      def records
        @filtered_records || (@records ||= sources.flat_map { |source| source.records(record_class) })
      end

      def items
        sequence = source.parsed_selector

        records.select do |record|
          segments = record.parsed_selector&.segments

          segments && segments.last.is_a?(Integer) && record.parsed_selector.parent == sequence
        end
      end

      def written!
        reset!

        @filtered_records = nil if filtered?

        sources.each { |source| source.parent&.reset_attributes_cache! }
        record_class.reset_loaded!(except: self)
      end

      def resolve(record_or_id)
        return record_or_id if record_or_id.is_a?(Base)

        records.find { |record| record.id.to_s == record_or_id.to_s }
      end

      def resolve_id(record_or_id)
        record_or_id.is_a?(Base) ? record_or_id.id : record_or_id.to_s
      end

      def insert_position(at:, before:, after:)
        return at if at
        return items.index(resolve(before)) || raise(ArgumentError, "No record #{before.inspect}") if before
        return (items.index(resolve(after)) || raise(ArgumentError, "No record #{after.inspect}")) + 1 if after

        nil
      end

      def build_index(field)
        list_field, item_field = included_selector(field)
        positions = {}
        included_positions = {}

        records.each_with_index do |record, position|
          value = record[field]
          positions[value.to_s] ||= position if value.present?

          next unless list_field

          Array(record[list_field]).each do |item|
            included = item_field ? (item[item_field] if item.is_a?(Hash)) : item
            included_positions[included.to_s] ||= position if included.present?
          end
        end

        LazyIndex.new(positions, included_positions, collection: self)
      end

      def included_selector(field)
        selector = record_class.try(:index_options)&.dig(field, :include)
        return unless selector

        list_field, item_field = selector.to_s.split("[]", 2)

        [list_field, item_field.delete_prefix(".").presence]
      end
    end
  end
end
