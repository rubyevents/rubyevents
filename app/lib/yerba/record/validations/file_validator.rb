# frozen_string_literal: true

module Yerba
  module Record
    module Validations
      # Validates a file named by `has_file` (or a FileRecord's own file):
      #
      #   validates :avatar, file: {presence: true}
      #   validates :avatar, file: {dimensions: {width: 256, height: 256}}
      #
      # A missing file is reported on the record, a file with the wrong dimensions on the file itself.
      #
      class FileValidator < ActiveModel::EachValidator
        OPTIONS = %i[presence dimensions].freeze

        def validate_each(record, attribute, value)
          path = value.respond_to?(:to_path) ? Pathname.new(value.to_path) : nil
          exists = path&.exist?

          if options[:presence] && !exists
            record.errors.add(attribute, :missing_file, **error_options, message: options[:message] || "file is missing#{" at #{relative(record, path)}" if path}")
          end

          validate_dimensions(record, attribute, path) if exists && options[:dimensions]
        end

        private

        def error_options
          options.except(*OPTIONS, :message)
        end

        def validate_dimensions(record, attribute, path)
          expected = options[:dimensions]
          expected = expected.call(path) if expected.respond_to?(:call)
          return unless expected

          width, height = FastImage.size(path.to_s)
          return if width.nil? || height.nil? || (width == expected[:width] && height == expected[:height])

          record.errors.add(attribute, :dimensions, **error_options, file_path: path.to_s, message: "dimensions are #{width}x#{height}, expected #{expected[:width]}x#{expected[:height]}")
        end

        def relative(record, path)
          root = record.try(:path_root) || record.class.root

          Pathname.new(path.to_s).relative_path_from(Pathname.new(root.to_s)).to_s
        end
      end
    end
  end
end
