# frozen_string_literal: true

module Yerba
  module Record
    module Validations
      # Checks that a value isn't used by any other record of the model:
      #
      #   validates :id, uniqueness: true
      #   validates :id, uniqueness: {also: :old_id}   # id and old_id share one namespace
      #
      # It looks at every record of the model, so it's usually declared with `on: :lint`. A record read
      # from outside the model's root (like a file in a temp folder) is only compared with its own file.
      #
      class UniquenessValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          return if value.blank?

          others = references(record)[value.to_s].reject { |other, _key| same_record?(other, record) }
          return if others.empty?

          locations = others.map { |other, key| "#{other.project_file_path}:#{other.source_line(key) || 1}" }

          record.errors.add(attribute, :taken, **options.except(:also, :message), value: value, message: options[:message] || %("#{value}" is not unique, it is also used at #{locations.join(", ")}))
        end

        private

        def same_record?(other, record)
          File.expand_path(other.file_path.to_s) == File.expand_path(record.file_path.to_s) && other.selector == record.selector
        end

        def keys
          [*attributes, *Array(options[:also])].map(&:to_s).uniq
        end

        def references(record)
          model = record.class

          if File.expand_path(record.path_root.to_s) == File.expand_path(model.root.to_s)
            model.all.cached([:uniqueness, keys]) { index(model.all) }
          else
            Yerba::Record::Validations.cached(self.class, record.file_path, keys) { index(record.file_records) }
          end
        end

        def index(records)
          records.each_with_object(Hash.new { |hash, value| hash[value] = [] }) do |record, references|
            keys.each { |key| references[record[key].to_s] << [record, key] if record[key].present? }
          end
        end
      end
    end
  end
end
