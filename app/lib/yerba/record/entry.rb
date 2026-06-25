# frozen_string_literal: true

module Yerba
  module Record
    class Entry
      class << self
        def references(name, class_name: nil, resolver: nil, creator: nil)
          define_method(name) do
            raw = self[name.to_s] || []

            resolved_resolver = resolver || default_resolver_for(name, class_name)
            resolved_creator = creator || default_creator_for(name, class_name)

            ReferencesProxy.new(
              raw: raw,
              resolver: resolved_resolver,
              creator: resolved_creator,
              entry: self
            )
          end
        end
      end

      attr_reader :document, :index

      def initialize(document:, index: nil)
        @document = document
        @index = index
      end

      def [](key)
        node[key.to_s]
      end

      def []=(key, value)
        node[key.to_s] = value
      end

      def save!
        document.save!
      end

      def destroy
        raise "Cannot destroy an entry without an index" if @index.nil?

        document.root.delete_at(@index)
        document.save!
      end

      def to_h
        node.to_h
      end

      def inspect
        "#<#{self.class.name} #{node.to_h.inspect}>"
      end

      private

      def node
        @index ? document.root[@index] : document.root
      end

      def default_resolver_for(field_name, class_name)
        collection_class = resolve_collection_class(field_name, class_name)
        return ->(value) { value } unless collection_class

        ->(value) { collection_class.find_by(name: value) }
      end

      def default_creator_for(field_name, class_name)
        collection_class = resolve_collection_class(field_name, class_name)
        return nil unless collection_class

        ->(value) { collection_class.find_or_create_by(name: value) }
      end

      def resolve_collection_class(field_name, class_name)
        name = class_name || field_name.to_s.classify.pluralize
        "Static::#{name}".safe_constantize
      end

      def method_missing(name, *args)
        field = name.to_s

        if field.end_with?("=")
          self[field.chomp("=")] = args.first
        elsif node.respond_to?(:key?) && node.key?(field)
          node[field]
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        field = name.to_s.chomp("=")
        name.to_s.end_with?("=") || (node.respond_to?(:key?) && node.key?(field)) || super
      end
    end
  end
end
