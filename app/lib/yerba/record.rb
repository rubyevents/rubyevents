# frozen_string_literal: true

module Yerba
  module Record
    def self.validate_all(models = validated_models, context: :lint)
      Validations.caching do
        models.flat_map do |model|
          model.all.flat_map { |record| record.valid?(context) ? [] : record.errors.objects.dup }
        end
      end
    end

    def self.validate_file(path, context: :lint)
      Validations.caching do
        records_in_file(path).flat_map { |record| record.valid?(context) ? [] : record.errors.objects.dup }
      end
    end

    def self.records_in_file(path)
      path = File.expand_path(path.to_s)
      model = Base.descendants.find { |klass| klass.path && klass.path_pattern.match(path) }

      model ? with_nested(model.in_file(path).to_a) : []
    end

    def self.with_nested(records)
      records.flat_map do |record|
        nested = Associations.nested_owners.values.select { |owner, _name| owner == record.class.name }
        children = nested.flat_map { |_owner, name| record.public_send(name).to_a }

        [record, *with_nested(children)]
      end
    end

    def self.fix_all(records = nil, models: validated_models, only: nil)
      Validations.caching do
        records = records ? records.to_a : models.flat_map { |model| model.all.to_a }

        records.flat_map do |record|
          validators = record.class.validators.select { |validator| validator.respond_to?(:fix) }
          validators = validators.select { |validator| Array(only).any? { |klass| validator.is_a?(klass) } } if only

          validators.filter_map do |validator|
            changes = validator.fix(record).to_i
            next unless changes.positive?

            record.save!(validate: false) if record.try(:changed?)

            [record, validator, changes]
          end
        end
      end
    end

    def self.validated_models
      models = [*Base.descendants, *FileRecord.descendants]

      models.select { |model| (model.path || Associations.nested_owners.key?(model.name)) && model.validated? }
    end
  end
end
