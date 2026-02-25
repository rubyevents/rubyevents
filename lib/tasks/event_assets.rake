require "mini_magick"
require "fileutils"
require "gum"

namespace :event do
  desc "Generate event assets from a logo and background color (interactive wizard)"
  task generate_assets: :environment do
    wizard = EventAssetWizard.new
    wizard.run
  end
end

class EventAssetWizard
  def run
    check_dependencies!
    print_header
    event = prompt_for_event
    logo_path = prompt_for_logo
    background_color = prompt_for_background_color(event)
    text_color = prompt_for_text_color(background_color)

    print_summary(event, logo_path, background_color, text_color)

    return unless Gum.confirm("Proceed with asset generation?")

    generator = EventAssetGenerator.new(
      event: event,
      logo_path: logo_path,
      background_color: background_color,
      text_color: text_color
    )

    generate_with_spinner(generator)

    puts Gum.style("✓ Asset generation complete!", border: "rounded", foreground: "2", padding: "0 1")
  end

  private

  def check_dependencies!
    check_imagemagick_installed!
  end

  def check_imagemagick_installed!
    unless system("which magick > /dev/null 2>&1")
      puts "Error: ImageMagick 7+ is required"
      puts ""
      puts "Install with:"
      puts "  brew install imagemagick"
      puts ""
      puts "Or see: https://imagemagick.org/script/download.php"
      exit 1
    end

    version_output = `magick --version 2>&1`.lines.first.to_s
    version_match = version_output.match(/ImageMagick (\d+)\./)

    unless version_match && version_match[1].to_i >= 7
      puts "Error: ImageMagick 7+ is required (found: #{version_output.strip})"
      puts ""
      puts "Upgrade with:"
      puts "  brew upgrade imagemagick"
      exit 1
    end
  end

  def print_header
    puts Gum.style("Event Asset Generator", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
  end

  def prompt_for_event
    all_slugs = Event.order(:slug).pluck(:slug)

    puts Gum.style("Missing an event? Run bin/rails db:seed:all to sync all from data/", foreground: "8")
    slug = Gum.filter(all_slugs, header: "Select event:", placeholder: "Type to filter...")

    if slug.blank?
      puts Gum.style("No event selected", foreground: "1")
      if Gum.confirm("Try again?")
        return prompt_for_event
      else
        exit 1
      end
    end

    event = Event.find_by(slug: slug)

    puts Gum.style("✓ #{event.name}", foreground: "2")
    event
  end

  def prompt_for_logo
    puts Gum.style("Select logo file (ESC to enter path manually):", foreground: "6")
    path = Gum.file(height: 15)

    if path.blank?
      path = Gum.input(header: "Enter logo path:", placeholder: "~/Downloads/logo.png")

      if path.blank?
        puts Gum.style("No file selected", foreground: "1")
        if Gum.confirm("Try again?")
          return prompt_for_logo
        else
          exit 1
        end
      end
    end

    expanded_path = File.expand_path(path)

    unless File.exist?(expanded_path)
      puts Gum.style("File not found: #{expanded_path}", foreground: "1")
      if Gum.confirm("Try again?")
        return prompt_for_logo
      else
        exit 1
      end
    end

    begin
      image = MiniMagick::Image.open(expanded_path)
      puts Gum.style("✓ #{File.basename(path)} (#{image.width}x#{image.height} #{image.type})", foreground: "2")
    rescue => e
      puts Gum.style("Invalid image: #{e.message}", foreground: "1")
      if Gum.confirm("Try again?")
        return prompt_for_logo
      else
        exit 1
      end
    end

    expanded_path
  end

  def prompt_for_background_color(event)
    default = begin
      event.static_metadata.featured_background
    rescue
      nil
    end
    default ||= "#000000"

    color = Gum.input(header: "Background color:", placeholder: default, value: default)
    color = default if color.blank?
    color = "##{color}" unless color.start_with?("#")

    unless valid_hex_color?(color)
      Gum.style("Invalid hex color. Use format like #CC342D", foreground: "1")
      return prompt_for_background_color(event)
    end

    Gum.style("✓ Background: #{color}", foreground: "2")
    color
  end

  def prompt_for_text_color(background_color)
    auto_color = calculate_text_color(background_color)

    choice = Gum.choose(["Auto (#{auto_color})", "Custom"])

    if choice.start_with?("Auto")
      Gum.style("✓ Text color: #{auto_color} (auto)", foreground: "2")
      return auto_color
    end

    color = Gum.input(header: "Text color:", placeholder: "#FFFFFF")
    color = "##{color}" unless color.start_with?("#")

    unless valid_hex_color?(color)
      Gum.style("Invalid hex color", foreground: "1")
      return prompt_for_text_color(background_color)
    end

    Gum.style("✓ Text color: #{color}", foreground: "2")
    color
  end

  def print_summary(event, logo_path, background_color, text_color)
    assets_list = EventAssetGenerator::ASSETS.map { |name, dims| "  • #{name}.webp (#{dims[:width]}x#{dims[:height]})" }.join("\n")

    summary = <<~SUMMARY
      Event:      #{event.name} (#{event.slug})
      Logo:       #{File.basename(logo_path)}
      Background: #{background_color}
      Text:       #{text_color}

      Assets to generate:
      #{assets_list}

      Output: #{event.data_folder}
    SUMMARY

    puts Gum.style(summary.gsub("'", "\\'"), border: "rounded", padding: "0 1", margin: "1 0", border_foreground: "6")
  end

  def generate_with_spinner(generator)
    puts ""

    generator.ensure_output_dir!

    EventAssetGenerator::ASSETS.each do |name, dimensions|
      Gum.spin("Generating #{name}.webp...", spinner: "dot") do
        generator.generate_asset(name, dimensions[:width], dimensions[:height])
      end
    end

    Gum.spin("Updating event.yml...", spinner: "dot") do
      generator.update_event_yml
    end
  end

  def valid_hex_color?(color)
    color.match?(/^#[0-9A-Fa-f]{6}$/)
  end

  def calculate_text_color(bg_color)
    hex = bg_color.delete("#")
    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    (luminance > 0.5) ? "#000000" : "#FFFFFF"
  end
end

class EventAssetGenerator
  ASSETS = {
    banner: {width: 1300, height: 350},
    card: {width: 600, height: 350},
    avatar: {width: 256, height: 256},
    featured: {width: 615, height: 350},
    poster: {width: 600, height: 350}
  }.freeze

  LOGO_PADDING_RATIO = 0.15

  attr_reader :event, :logo_path, :background_color, :text_color, :output_dir

  def initialize(event:, logo_path:, background_color:, text_color: nil)
    @event = event
    @logo_path = logo_path
    @background_color = normalize_color(background_color)
    @text_color = text_color.present? ? normalize_color(text_color) : calculate_text_color(@background_color)
    @output_dir = Rails.root.join("app", "assets", "images", "events", event.series.slug, event.slug)
  end

  def ensure_output_dir!
    FileUtils.mkdir_p(output_dir)
  end

  def generate_all
    ensure_output_dir!

    puts "Generating assets for #{event.name}..."
    puts "  Logo: #{logo_path}"
    puts "  Background: #{background_color}"
    puts "  Output: #{output_dir}"
    puts ""

    ASSETS.each do |name, dimensions|
      generate_asset(name, dimensions[:width], dimensions[:height])
    end

    puts ""
    puts "Done! Generated #{ASSETS.size} assets."
  end

  def generate_asset(name, width, height)
    output_path = output_dir.join("#{name}.webp")

    logo = MiniMagick::Image.open(logo_path)
    logo_aspect = logo.width.to_f / logo.height.to_f

    padding = [width, height].min * LOGO_PADDING_RATIO
    max_logo_width = width - (padding * 2)
    max_logo_height = height - (padding * 2)

    if max_logo_width / logo_aspect <= max_logo_height
      scaled_width = max_logo_width.round
      scaled_height = (max_logo_width / logo_aspect).round
    else
      scaled_height = max_logo_height.round
      scaled_width = (max_logo_height * logo_aspect).round
    end

    cmd = [
      "magick",
      "-size", "#{width}x#{height}",
      "xc:#{background_color}",
      "(", logo_path, "-resize", "#{scaled_width}x#{scaled_height}", ")",
      "-gravity", "center",
      "-composite",
      "-quality", "90",
      output_path.to_s
    ]

    system(*cmd, exception: true)

    puts "  Created #{name}.webp (#{width}x#{height})"
  rescue => e
    puts "  Error creating #{name}.webp: #{e.message}"
    puts "    #{e.backtrace.first(3).join("\n    ")}"
  end

  def update_event_yml
    event_yml_path = event.data_folder.join("event.yml")

    unless event_yml_path.exist?
      puts "Warning: event.yml not found at #{event_yml_path}"
      return
    end

    content = File.read(event_yml_path)

    if content.match?(/^banner_background:/)
      content.gsub!(/^banner_background:.*$/, "banner_background: \"#{background_color}\"")
    else
      content = content.rstrip + "\nbanner_background: \"#{background_color}\"\n"
    end

    if content.match?(/^featured_background:/)
      content.gsub!(/^featured_background:.*$/, "featured_background: \"#{background_color}\"")
    else
      content = content.rstrip + "\nfeatured_background: \"#{background_color}\"\n"
    end

    if content.match?(/^featured_color:/)
      content.gsub!(/^featured_color:.*$/, "featured_color: \"#{text_color.delete("#")}\"")
    else
      content = content.rstrip + "\nfeatured_color: \"#{text_color.delete("#")}\"\n"
    end
    updated = true

    if updated
      File.write(event_yml_path, content)
      puts ""
      puts "Updated event.yml:"
      puts "  banner_background: #{background_color}"
      puts "  featured_background: #{background_color}"
      puts "  featured_color: #{text_color}"
    end
  end

  private

  def normalize_color(color)
    return color if color.start_with?("#")

    "##{color}"
  end

  def calculate_text_color(bg_color)
    hex = bg_color.delete("#")
    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    (luminance > 0.5) ? "#000000" : "#FFFFFF"
  end
end
