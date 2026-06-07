# frozen_string_literal: true

module Static
  module Validators
    class AssetDimensions
      PATTERNS = ["**/*.webp"].freeze

      EXPECTED_DIMENSIONS = {
        "avatar.webp" => {width: 256, height: 256},
        "banner.webp" => {width: 1300, height: 350},
        "card.webp" => {width: 600, height: 350},
        "featured.webp" => {width: 615, height: 350},
        "poster.webp" => {width: 600, height: 350},
        "sticker.webp" => {width: 350, height: 350},
        "stamp.webp" => {width: 512, height: 512}
      }.freeze

      GENERATED_ASSET_DIMENSIONS = EXPECTED_DIMENSIONS.slice(
        "banner.webp",
        "card.webp",
        "avatar.webp",
        "featured.webp",
        "poster.webp"
      ).transform_keys { |filename| File.basename(filename, ".webp").to_sym }.freeze

      def initialize(file_path:)
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
          filename = File.basename(path_or_filename.to_s)

          return EXPECTED_DIMENSIONS[filename] if EXPECTED_DIMENSIONS.key?(filename)
          return EXPECTED_DIMENSIONS["sticker.webp"] if filename.match?(/\Asticker(?:-[^.]+)?\.webp\z/)
          return EXPECTED_DIMENSIONS["stamp.webp"] if filename.match?(/\Astamp(?:-[^.]+)?\.webp\z/)

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
