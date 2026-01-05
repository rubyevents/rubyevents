# frozen_string_literal: true

module IconHelper
  SIZE_CLASSES = {
    xs: "h-4 w-4",
    sm: "h-5 w-5",
    md: "h-6 w-6",
    lg: "h-8 w-8",
    xl: "h-10 w-10"
  }

  # Add a class-level cache
  @svg_cache = {}

  class << self
    attr_reader :svg_cache

    def clear_cache
      @svg_cache.clear
    end
  end

  def cached_inline_svg(path, **options)
    cache_key = [path, options].hash

    IconHelper.svg_cache[cache_key] ||= begin
      full_path = Rails.root.join("app", "assets", "images", path)

      unless File.exist?(full_path)
        basename = File.basename(path, ".svg")
        match = basename.match(/^(.+?)(?:-(brands))?-(solid|regular|light)$/)

        if match
          icon_name, type, style = match.captures
          folder = type || style
          search_url = "https://fontawesome.com/search?q=#{CGI.escape(icon_name)}"
          github_url = "https://raw.githubusercontent.com/FortAwesome/Font-Awesome/7.x/svgs-full/#{folder}/#{icon_name}.svg"
          curl_command = "curl -f -o #{full_path} \"#{github_url}\""

          raise ArgumentError, "Icon not found. Download from\n#{search_url}\nand save to\n#{full_path}\n\nOr run the following curl command (only works for free icons, not Pro):\n#{curl_command}"
        else
          raise ArgumentError, "Icon not found: #{path}"
        end
      end

      svg_content = File.read(full_path)

      if options.present?
        # Extract existing attributes from the SVG tag
        svg_tag = svg_content[/<svg[^>]*>/]

        existing_attributes = {}
        svg_tag.scan(/([^\s=]+)="([^"]*)"/).each do |name, value|
          existing_attributes[name] = value
        end.to_h

        new_attributes = tag.attributes(existing_attributes.merge(options))

        # Replace the opening SVG tag with our modified version
        new_svg_tag = "<svg #{new_attributes}>"
        svg_content.sub!(/<svg[^>]*>/, new_svg_tag)
      end

      svg_content.html_safe
    end
  end

  def fontawesome(icon_name, size: :md, type: nil, style: :solid, **options)
    classes = class_names(SIZE_CLASSES[size], options[:class])
    cached_inline_svg "icons/fontawesome/#{[icon_name, type, style].compact.join("-")}.svg", class: classes, **options.except(:class)
  end

  def fab(icon_name, **options)
    fontawesome(icon_name, type: :brands, **options.except(:type))
  end

  def fa(icon_name, **options)
    fontawesome(icon_name, **options.except(:type))
  end

  def icon(icon_name, size: :md, **options)
    classes = class_names(SIZE_CLASSES[size], options.delete(:class))
    cached_inline_svg("icons/icn-#{icon_name}.svg", class: classes, **options)
  end
end
