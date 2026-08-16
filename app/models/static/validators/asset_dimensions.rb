# frozen_string_literal: true

module Static
  module Validators
    class AssetDimensions
      PATTERNS = ["**/*.webp"].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        expected = self.class.expected_dimensions_for(@file_path)
        return [] unless expected

        actual = self.class.dimensions_for(@file_path)
        return [] if actual.nil? || actual == expected

        [Static::Validators::Error.new(
          "Asset dimensions are #{actual[:width]}x#{actual[:height]}, expected #{expected[:width]}x#{expected[:height]}",
          file_path: @file_path,
          line: 1
        )]
      end

      class << self
        def expected_dimensions_for(path_or_filename)
          filename = File.basename(path_or_filename.to_s, ".webp")

          return ::Event::Assets::DIMENSIONS[filename] if ::Event::Assets::DIMENSIONS.key?(filename)
          return ::Event::Assets::DIMENSIONS["sticker"] if filename.match?(/\Asticker(?:-[^.]+)?\z/)
          return ::Event::Assets::DIMENSIONS["stamp"] if filename.match?(/\Astamp(?:-[^.]+)?\z/)

          nil
        end

        def dimensions_for(path)
          width, height = FastImage.size(path.to_s)
          return nil if width.nil? || width.zero? || height.nil? || height.zero?

          {width: width, height: height}
        end
      end
    end
  end
end
