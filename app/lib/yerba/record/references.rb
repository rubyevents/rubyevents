# frozen_string_literal: true

module Yerba
  module Record
    module References
      extend ActiveSupport::Concern

      class_methods do
        def references(name, class_name: nil, resolver: nil, creator: nil)
          define_method(name) do
            # Reads are served from the cached values, the CST node is only looked up when writing
            raw = lambda do
              raw_value = node[name.to_s]

              if raw_value.respond_to?(:each)
                raw_value
              else
                (raw_value ? [raw_value] : [])
              end
            end

            resolved_resolver = resolver || default_resolver_for(name, class_name)
            resolved_creator = creator || default_creator_for(name, class_name)

            ReferencesProxy.new(
              raw: raw,
              values: Array(self[name.to_s]),
              resolver: resolved_resolver,
              creator: resolved_creator,
              entry: self
            )
          end
        end
      end

      private

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
    end
  end
end
