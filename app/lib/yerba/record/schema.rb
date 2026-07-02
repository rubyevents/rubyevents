# frozen_string_literal: true

module Yerba
  module Record
    module Schema
      extend ActiveSupport::Concern

      class_methods do
        def schema(schema_class = nil, &block)
          if block
            @schema = Class.new(RubyLLM::Schema, &block)
            define_schema_methods
          elsif schema_class
            @schema = schema_class
            define_schema_methods
          end

          @schema
        end

        def create(**attributes)
          record = new(**attributes)
          record.save!

          unload!

          record
        end

        private

        def define_schema_methods
          @schema.properties.each do |field_name, _property|
            name = field_name.to_s

            define_method(name) { self[name] } unless method_defined?(name)
            define_method(:"#{name}=") { |value| self[name] = value } unless method_defined?(:"#{name}=")
            define_method(:"#{name}?") { self[name].present? } unless method_defined?(:"#{name}?")
          end
        end
      end
    end
  end
end
