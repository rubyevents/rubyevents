require "rqrcode"
require "fileutils"
require "chunky_png"
require "mini_magick"

MAIN_PATH = "https://rubyevents.org/profiles/connect"

# ensure qrs directory exists
FileUtils.mkdir_p("qrs")

ids = File.read("ids.csv").split("\n")

# if the --test flag is passed, only process the first 10 ids
if ARGV.include?("--test")
  ids = ids.first(5)
  # delete the directory qrs
  FileUtils.rm_rf("qrs")
  FileUtils.mkdir_p("qrs")
end

# if --from=0 and --to=100 is passed, only process the ids from 0 to 100
from_arg = ARGV.find { |arg| arg.start_with?("--from=") }
to_arg = ARGV.find { |arg| arg.start_with?("--to=") }

if from_arg && to_arg
  from = from_arg.split("=")[1].to_i
  to = to_arg.split("=")[1].to_i
  ids = ids[from..to]
  puts ["from->", from, "to->", to, "first->", ids.first, "last->", ids.last].inspect
end

ids.each do |id|
  qr = RQRCode::QRCode.new("#{MAIN_PATH}/#{id}")

    # Generate QR code as PNG with full color support
  qr_png = qr.as_png(size: 1800, color_mode: ChunkyPNG::COLOR_TRUECOLOR)

  # Create temporary file for QR code
  temp_qr_path = "temp_qr_#{id}.png"
  File.write(temp_qr_path, qr_png.to_s)

  # Load the QR code
  image = MiniMagick::Image.open(temp_qr_path)

  # Force color mode by adding a tiny colored pixel that will be covered later
  image.combine_options do |c|
    c.fill "red"
    c.draw "point 0,0"  # Add a red pixel at corner (will be covered by QR)
    c.colorspace "sRGB"
    c.type "TrueColor"
    c.depth "8"
  end

  # Get QR code dimensions
  qr_width = image.width
  qr_height = image.height

  # QR codes have a structure - we need to align to the module grid
  qr_version = qr.modules.size
  module_size = qr_width / qr_version

  # Calculate optimal logo size (should not exceed ~25% of QR code for readability)
  max_logo_size = (qr_width * 0.25).to_i

    # Load and resize logo while preserving colors
  logo = MiniMagick::Image.open("ruby_logo.jpg")

  # Ensure we preserve the color space and alpha channel
  logo.format "png"
  logo.colorspace "sRGB"

  # Resize logo if needed, using high-quality resampling
  if logo.width > max_logo_size || logo.height > max_logo_size
    logo.combine_options do |c|
      c.resize "#{max_logo_size}x#{max_logo_size}"
      c.filter "Lanczos"  # High-quality resampling
      c.colorspace "sRGB"  # Preserve color space
    end
  end

  logo_width = logo.width
  logo_height = logo.height

  # Calculate center position
  center_x = qr_width / 2
  center_y = qr_height / 2

  logo_x = (center_x - logo_width / 2)
  logo_y = (center_y - logo_height / 2)

  # Calculate text dimensions - we want the text width to match logo width
  text_content = id.upcase

  # Use a simple approach to estimate font size based on logo width
  # Average character width is roughly 0.6 * font_size for Arial Bold
  target_width = logo_width * 0.9  # Use 90% of logo width for some padding
  estimated_font_size = (target_width / (text_content.length * 0.6)).to_i
  font_size = [[estimated_font_size, 16].max, 54].min  # Clamp between 16 and 48
  # puts ["font_size->", font_size].inspect

  # Calculate text height for positioning
  text_height = (font_size * 1.2).to_i  # Approximate text height

  # Calculate expanded background dimensions to include text
  bg_padding = 8
  text_spacing = 8  # Space between logo and text

  top_offset = 0 # offset from top of the QR code to the logo

  total_content_height = logo_height + text_spacing + text_height - top_offset
  bg_width = logo_width + (bg_padding * 2) + 1
  bg_height = total_content_height + (bg_padding * 2) + 1 - 30
  bg_height = bg_width

  bg_x = (center_x - bg_width / 2) - 1
  bg_y = (center_y - total_content_height / 2 - bg_padding) - 1

  # Draw white background rectangle
  image.combine_options do |c|
    c.fill "white"
    c.draw "rectangle #{bg_x},#{bg_y} #{bg_x + bg_width},#{bg_y + bg_height}"
  end

  # Position logo in the background
  logo_final_x = (center_x - logo_width / 2)
  logo_final_y = (bg_y + bg_padding)

  # Composite logo onto QR code with proper alpha blending
  image = image.composite(logo) do |c|
    c.compose "Over"
    c.geometry "+#{logo_final_x}+#{logo_final_y}"
    c.alpha "Set"  # Ensure alpha channel is properly handled
  end

  # Add text below logo
  text_y = logo_final_y + logo_height + text_spacing + (text_height / 2) - top_offset - 90

  image.combine_options do |c|
    c.fill "black"
    c.font "Arial-Bold"
    c.pointsize font_size
    c.gravity "center"
    c.annotate "+0+#{text_y - center_y}", text_content
  end

  # Save the final image with color preservation
  qr_path = "qrs/#{id}.png"
  image.combine_options do |c|
    c.colorspace "sRGB"
    c.type "TrueColor"
    c.depth "8"
    c.define "png:color-type=2"  # Force RGB color type
  end
  image.write(qr_path)

  # Clean up temporary files
  File.delete(temp_qr_path)
  puts ["processed->", id].inspect
end

