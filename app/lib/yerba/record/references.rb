# frozen_string_literal: true

module Yerba
  module Record
    module References
      extend ActiveSupport::Concern

      Declaration = Data.define(:owner, :field, :target)

      def self.declarations
        @declarations ||= {}
      end

      class_methods do
        def references(name, class_name: nil, resolver: nil, creator: nil)
          target = class_name.is_a?(Class) ? class_name.name : (class_name || infer_class_name(name, singularize: true))
          References.declarations[[self.name, name.to_s]] = Declaration.new(owner: self.name, field: name.to_s, target: target)

          define_method(name) do
            raw = lambda do
              raw_value = node[name.to_s]

              if raw_value.respond_to?(:each)
                raw_value
              else
                (raw_value ? [raw_value] : [])
              end
            end

            resolved_resolver = resolver || default_resolver_for(target)
            resolved_creator = creator || default_creator_for(target)

            ReferencesProxy.new(
              raw: raw,
              values: Array(self[name.to_s]),
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
                  Reference.new(value: item, record: record, selector: "#{declaration.field}[#{index}]") if item.present?
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

      def default_resolver_for(target)
        record_class = target.safe_constantize
        return ->(value) { value } unless record_class

        ->(value) { record_class.find_by(name: value) }
      end

      def default_creator_for(target)
        record_class = target.safe_constantize
        return nil unless record_class.respond_to?(:find_or_create_by)

        ->(value) { record_class.find_or_create_by(name: value) }
      end
    end
  end
end
