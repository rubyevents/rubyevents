# frozen_string_literal: true

module Yerba
  module Record
    class Base
      include Querying
      include Indexing
      include References
      include Associations
      include Schema

      attr_reader :document, :index

      def initialize(attributes = nil, document: nil, index: nil, file_path: nil, **kwargs)
        if document
          @document = document
          @index = index
          @file_path = file_path
          @new_record = false
        elsif attributes.is_a?(Hash) || kwargs.any?
          attrs = (attributes || {}).merge(kwargs).transform_keys(&:to_s)
          @document = Yerba::Record::Document.from(attrs)
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
        if scalar_node?
          (key.to_s == self.class.scalar_field) ? unwrap(node) : nil
        else
          unwrap(node[key.to_s])
        end
      end

      def []=(key, value)
        if scalar_node?
          document.root[@index] = value if key.to_s == self.class.scalar_field
        else
          node[key.to_s] = value
        end
      end

      def save!
        if new_record?
          path = persist_path
          raise "Cannot save: no persist_path defined" unless path

          dir = File.dirname(path)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)

          validate! if self.class.schema

          document.save_to!(path)

          @new_record = false
          @was_new_record = true
        else
          document.save!
        end
      end

      def destroy
        raise "Cannot destroy a record without an index" if @index.nil?

        document.root.delete_at(@index)
        document.save!
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

        json_schema = JSON.parse(self.class.schema.new.to_json_schema[:schema].to_json)
        schemer = JSONSchemer.schema(json_schema)
        errors = schemer.validate(to_h).to_a

        if errors.any?
          error_messages = errors.map { |error| "#{error["error"]} at #{error["data_pointer"]}" }
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

        Pathname.new(file_path).relative_path_from(self.class.base_path).to_s
      end

      def attributes
        to_h
      end

      def to_h
        if scalar_node?
          {self.class.scalar_field => unwrap(node)}
        else
          document&.yerba&.value_at(node.respond_to?(:selector) ? node.selector : "") || {}
        end
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
        @index ? document.root[@index] : document.root
      end

      def scalar_node?
        self.class.scalar_field && node.is_a?(Yerba::Scalar)
      end

      private

      def unwrap(value)
        case value
        when Yerba::Scalar then value.value
        when Yerba::Sequence then value.map { |item| unwrap(item) }
        when Yerba::Map then value.to_h
        else value
        end
      end

      def method_missing(name, *args)
        field = name.to_s

        if field.end_with?("=")
          self[field.chomp("=")] = args.first
        elsif field.end_with?("?")
          self[field.chomp("?")].present?
        elsif node.respond_to?(:key?) && node.key?(field)
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
        return true if node.respond_to?(:key?) && node.key?(field)
        return true if @attributes&.key?(field)

        false
      end
    end
  end
end
