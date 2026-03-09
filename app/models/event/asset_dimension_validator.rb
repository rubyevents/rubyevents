require "mini_magick"

class Event::AssetDimensionValidator
  IMAGE_ROOT = Rails.root.join("app", "assets", "images", "events")

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

  def self.expected_dimensions_for(path_or_filename)
    filename = File.basename(path_or_filename.to_s)

    return EXPECTED_DIMENSIONS[filename] if EXPECTED_DIMENSIONS.key?(filename)
    return EXPECTED_DIMENSIONS["sticker.webp"] if filename.match?(/\Asticker(?:-[^.]+)?\.webp\z/)
    return EXPECTED_DIMENSIONS["stamp.webp"] if filename.match?(/\Astamp(?:-[^.]+)?\.webp\z/)

    nil
  end

  def self.dimensions_for(path)
    output = MiniMagick::Tool.new("identify") do |identify|
      identify.format("%w %h")
      identify << path.to_s
    end

    width, height = output.to_s.strip.split.map(&:to_i)
    return nil if width.zero? || height.zero?

    {width: width, height: height}
  end

  def self.warnings(image_root: IMAGE_ROOT)
    Dir.glob(image_root.join("**", "*.webp")).filter_map do |path|
      expected = expected_dimensions_for(path)
      next unless expected

      actual = dimensions_for(path)
      next if actual.nil? || actual == expected

      {
        path: Pathname.new(path).relative_path_from(image_root).to_s,
        actual: actual,
        expected: expected
      }
    rescue MiniMagick::Error, MiniMagick::Invalid => e
      {
        path: Pathname.new(path).relative_path_from(image_root).to_s,
        error: e.message
      }
    end
  end
end
