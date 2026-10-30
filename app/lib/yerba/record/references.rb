# frozen_string_literal: true

module Yerba
  module Record
    module References
      extend ActiveSupport::Concern

      # field — the key in the YAML holding the reference(s), `name` unless given
      # key   — the key inside a hash item that holds the referenced value, like `name` in `{name:, from:}`
      Declaration = Data.define(:owner, :field, :target, :key)

      def self.declarations
        @declarations ||= {}
      end

      def self.reference_name(item)
        reference_value(item, "name")
      end

      def self.reference_value(item, key = "name")
        item.is_a?(Hash) ? item[key] : item
      end

      class_methods do
        def references(name, class_name: nil, resolver: nil, creator: nil, field: nil, key: "name")
          field = (field || name).to_s
          target = class_name.is_a?(Class) ? class_name.name : (class_name || infer_class_name(name, singularize: true))
          References.declarations[[self.name, name.to_s]] = Declaration.new(owner: self.name, field: field, target: target, key: key)

          define_method(name) do
            raw = lambda do
              raw_value = node[field]

              if raw_value.respond_to?(:each)
                raw_value
              else
                (raw_value ? [raw_value] : [])
              end
            end

            resolved_resolver = resolver || default_resolver_for(target, key)
            resolved_creator = creator || default_creator_for(target, key)

            ReferencesProxy.new(
              raw: raw,
              values: Array(self[field]).map { |item| References.reference_value(item, key) },
              resolver: resolved_resolver,
              creator: resolved_creator,
              entry: self
            )
          end
        end

        def inbound_references
          References.declarations.values.select { |declaration| declaration.target == name }.flat_map do |declaration|
            declaration.owner.constantize.all.flat_map do |record|
              value = record[declaration.field]

              if value.is_a?(Array)
                value.each_with_index.filter_map do |item, index|
                  selector = item.is_a?(Hash) ? "#{declaration.field}[#{index}].#{declaration.key}" : "#{declaration.field}[#{index}]"
                  name = References.reference_value(item, declaration.key)

                  Reference.new(value: name, record: record, selector: selector) if name.present?
                end
              elsif value.present?
                [Reference.new(value: value, record: record, selector: declaration.field)]
              else
                []
              end
            end
          end
        end
      end

      private

      def default_resolver_for(target, key)
        record_class = target.safe_constantize
        return ->(value) { value } unless record_class

        ->(value) { record_class.find_by(key.to_sym => value) }
      end

      def default_creator_for(target, key)
        record_class = target.safe_constantize
        return nil unless record_class.respond_to?(:find_or_create_by)

        ->(value) { record_class.find_or_create_by(key.to_sym => value) }
      end
    end
  end
end
