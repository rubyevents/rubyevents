# frozen_string_literal: true

module Yerba
  module Record
    class Base
      include Querying
      include Indexing
      include References
      include Associations
      include Schema

      attr_reader :document, :parent
      attr_reader :parsed_selector

      def self.to_selector(selector)
        return selector if selector.is_a?(Yerba::Selector)
        return nil if selector.blank?

        Yerba::Selector.parse(selector.to_s)
      end

      def initialize(attributes = nil, document: nil, index: nil, selector: nil, file_path: nil, parent: nil, **kwargs)
        if document
          @document = document
          @parsed_selector = Base.to_selector(selector) || (index && Yerba::Selector.build([index]))
          @file_path = file_path
          @parent = parent
          @new_record = false
        elsif attributes.is_a?(Hash) || kwargs.any?
          attrs = (attributes || {}).merge(kwargs).transform_keys(&:to_s)
          @document = Yerba::Document.from(attrs)
          @new_record = true
        else
          @document = document
          @new_record = false
        end
      end

      def new_record?
        @new_record
      end

      def persisted?
        !new_record?
      end

      def [](key)
        attributes_cache[key.to_s]
      end

      def []=(key, value)
        reset_attributes_cache!

        if scalar_node?
          document.root[index] = value if key.to_s == self.class.scalar_field
        else
          node[key.to_s] = value
        end
      end

      def key?(key)
        attributes_cache.key?(key.to_s)
      end

      def insert(key, value, before: nil, after: nil)
        reset_attributes_cache!

        node.insert(key.to_s, value, before: before&.to_s, after: after&.to_s)
      end

      def delete(key)
        return unless key?(key)

        reset_attributes_cache!

        node.delete(key.to_s)
      end

      def source_location(key = nil)
        target = key ? node[key.to_s] : node

        target.respond_to?(:location) ? target.location : nil
      end

      def source_line(key = nil)
        source_location(key)&.start_line
      end

      def selector
        @selector ||= parsed_selector&.to_s
      end

      def index
        segment = parsed_selector&.segments&.last

        segment if segment.is_a?(Integer)
      end

      def nested?
        !parent.nil?
      end

      def save!
        if new_record?
          path = persist_path

          raise "Cannot save: no persist_path defined" unless path
          raise ArgumentError, "#{self.class.name} already exists at #{path}" if File.exist?(path)

          directory = File.dirname(path)
          FileUtils.mkdir_p(directory) unless File.directory?(directory)

          validate! if self.class.schema

          document.save_to!(path)

          @new_record = false
          @was_new_record = true
        else
          document.save!(apply: true)
        end

        reset_attributes_cache!

        self.class.reset_loaded!
      end

      def destroy
        raise "Cannot destroy a record without an index" if index.nil?

        document.remove_at(parsed_selector.parent.to_s, index)
        document.save!(apply: true)

        reset_attributes_cache!
        self.class.reset_loaded!
      end

      def update(**attributes)
        attributes.each { |key, value| self[key] = value }

        save!

        self
      end

      def changed?
        document.changed?
      end

      def validate!
        return unless self.class.schema

        errors = Yerba::Document.from(to_h).validate(self.class.schema.json_schema)

        if errors.any?
          error_messages = errors.map { |error| "#{error["message"]} at #{error["path"]}" }
          raise ArgumentError, "Validation failed: #{error_messages.join(", ")}"
        end
      end

      def id
        self["id"]
      end

      def file_path
        @file_path || document&.path
      end

      def relative_file_path
        return nil unless file_path && self.class.base_path

        @relative_file_path ||= Pathname.new(file_path).relative_path_from(self.class.base_path).to_s
      end

      def project_file_path
        return nil unless file_path

        Pathname.new(file_path).relative_path_from(Rails.root).to_s
      end

      def attributes
        to_h
      end

      def to_h
        attributes_cache.dup
      end

      def reset_attributes_cache!
        @attributes_cache = nil
        @relative_file_path = nil
        @nested_collections = nil
        parent&.reset_attributes_cache!
      end

      def ==(other)
        return super if new_record? || !other.is_a?(Base)

        other.class == self.class && other.document.equal?(document) && other.parsed_selector == parsed_selector
      end
      alias_method :eql?, :==

      def hash
        new_record? ? super : [self.class, document.object_id, parsed_selector].hash
      end

      def to_yaml
        node.respond_to?(:source) ? node.source : Yerba::Document.from(to_h).to_s
      end

      def inspect
        "#<#{self.class.name} #{to_h.inspect}>"
      end

      def persist_path
        nil
      end

      def node
        parsed_selector ? document[selector] : document.root
      end

      def scalar_node?
        self.class.scalar_field && node.is_a?(Yerba::Scalar)
      end

      private

      def attributes_cache
        @attributes_cache ||= if scalar_node?
          {self.class.scalar_field => unwrap(node)}
        else
          values = parsed_selector ? parsed_selector.dig(document&.values) : document&.values
          values.is_a?(Hash) ? values : {}
        end
      end

      def unwrap(value)
        case value
        when Yerba::Scalar
          value.value
        when Yerba::Sequence
          value.map { |item| unwrap(item) }
        when Yerba::Map
          value.to_h
        else
          value
        end
      end

      def method_missing(name, *args)
        field = name.to_s

        if field.end_with?("=")
          self[field.chomp("=")] = args.first
        elsif field.end_with?("?")
          self[field.chomp("?")].present?
        elsif attributes_cache.key?(field)
          self[field]
        elsif @attributes&.key?(field)
          self[field]
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        field = name.to_s.chomp("=").chomp("?")

        return true if name.to_s.end_with?("=")
        return true if attributes_cache.key?(field)
        return true if @attributes&.key?(field)

        false
      end
    end
  end
end
