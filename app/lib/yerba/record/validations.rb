# frozen_string_literal: true

module Yerba
  module Record
    # ActiveModel validations for records. Declared like in ActiveRecord:
    #
    #   validates :start_date, presence: true, unless: :meetup?
    #   validates :end_date, comparison: {greater_than_or_equal_to: :start_date}
    #   validates :kind, "static/inferred_kind": true
    #   validate :speakers_exist
    #   validate { errors.add(:base, "...") if ... }
    #
    # They run on save (context :create or :update). Validations declared with `on: :lint`
    # only run when the whole dataset is checked (see Yerba::Record.validate_all).
    #
    # An error added with `severity: :warning` is reported but doesn't block a save, and one added
    # with `at: "aliases[0].slug"` points at that node instead of the attribute (`at: :file` at the file).
    #
    # A validator that defines `fix(record)` can repair what it reports (see Yerba::Record.fix_all).
    #
    module Validations
      extend ActiveSupport::Concern

      def self.cached(*key)
        cache = Thread.current[:yerba_record_validation_cache]
        return yield unless cache

        cache.fetch(key) { cache[key] = yield }
      end

      def self.caching
        previous = Thread.current[:yerba_record_validation_cache]
        Thread.current[:yerba_record_validation_cache] = previous || {}

        yield
      ensure
        Thread.current[:yerba_record_validation_cache] = previous
      end

      included do
        include ActiveModel::Validations

        def self.human_attribute_name(attribute, _options = {})
          attribute.to_s
        end
      end

      class_methods do
        def validated?
          _validate_callbacks.any? { |callback| !callback.filter.is_a?(Validations::SchemaValidator) }
        end
      end

      def blocking_errors
        errors.reject { |error| error_warning?(error) }
      end

      def valid_for_save?(context = nil)
        valid?(context || (try(:new_record?) ? :create : :update))

        blocking_errors.empty?
      end

      def validate_for_save!(context = nil)
        raise RecordInvalid.new(self) unless valid_for_save?(context)
      end

      def error_file_path(error)
        (error.options[:file_path] || file_path).to_s
      end

      def error_location(error)
        return nil if error.options.key?(:file_path) || error.options[:at] == :file || !respond_to?(:source_location)

        key = error.options[:at] || (error.attribute unless error.attribute == :base)

        (source_location(key) if key) || source_location
      end

      def error_warning?(error)
        error.options[:severity] == :warning
      end
    end
  end
end
