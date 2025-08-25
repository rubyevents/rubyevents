require "prawn"
require "prawn/measurement_extensions"

# Get all PNG files from qrs directory and sort them alphabetically
qr_files = Dir.glob("qrs/*.png").sort

if qr_files.empty?
  puts "No PNG files found in qrs directory"
  exit 1
end

puts "Found #{qr_files.length} QR code images"

# A4 page dimensions in points (72 points per inch)
# A4 = 210 × 297 mm = 8.27 × 11.69 inches = 595 × 842 points
page_width = 595.28
page_height = 841.89

# Margins
margin = 36 # 0.5 inch margins

# Available space for content
content_width = page_width - (2 * margin)
content_height = page_height - (2 * margin)

# Calculate grid dimensions optimized for cutting (no spacing for labels)
def calculate_grid_layout(num_images, content_width, content_height)
  best_layout = nil
  best_image_size = 0

  # Try different numbers of columns
  (1..12).each do |cols|
    rows = (num_images.to_f / cols).ceil

    # Calculate image size for this grid (no extra space needed for labels)
    image_width = content_width / cols
    image_height = content_height / rows

    # Use the smaller dimension to maintain aspect ratio
    image_size = [image_width, image_height].min

    # Skip if images would be too small
    next if image_size < 40

    if image_size > best_image_size
      best_image_size = image_size
      best_layout = { cols: cols, rows: rows, image_size: image_size }
    end
  end

  best_layout
end

# Calculate how many images can fit per page (try to fit more without labels)
images_per_page = 30 # Start with more since we don't need space for labels
layout = calculate_grid_layout(images_per_page, content_width, content_height)

# If we can't fit 30 images nicely, try with fewer
if layout.nil?
  (1..30).reverse_each do |count|
    layout = calculate_grid_layout(count, content_width, content_height)
    if layout
      images_per_page = count
      break
    end
  end
end

if layout.nil?
  puts "Could not calculate a suitable layout"
  exit 1
end

puts "Using layout: #{layout[:cols]} columns × #{layout[:rows]} rows"
puts "Image size: #{layout[:image_size].round(2)} points"
puts "Images per page: #{images_per_page}"

# Create PDF
Prawn::Document.generate("qr_codes.pdf", page_size: "A4", margin: margin) do |pdf|
  pdf.font "Helvetica"

  qr_files.each_with_index do |file, index|
    # Start a new page if needed (except for the first image)
    if index > 0 && index % images_per_page == 0
      pdf.start_new_page
    end

    # Calculate position in grid
    page_index = index % images_per_page
    col = page_index % layout[:cols]
    row = page_index / layout[:cols]

        # Calculate x, y position (tight grid with no spacing)
    x = col * (content_width / layout[:cols])
    y = content_height - (row * (content_height / layout[:rows])) - (content_height / layout[:rows])

    # Draw the image (no labels, tight spacing for easy cutting)
    begin
      pdf.image file, at: [x, y + layout[:image_size]],
                      width: layout[:image_size],
                      height: layout[:image_size]

    rescue => e
      puts "Error processing #{file}: #{e.message}"
      # Draw a placeholder rectangle
      pdf.stroke_rectangle [x, y + layout[:image_size]], layout[:image_size], layout[:image_size]
    end
  end

  # Add page numbers
  total_pages = (qr_files.length.to_f / images_per_page).ceil
  (1..total_pages).each do |page_num|
    pdf.go_to_page(page_num)
    pdf.draw_text "Page #{page_num} of #{total_pages}",
                  at: [page_width - margin - 100, 20],
                  size: 10
  end
end

puts "PDF generated successfully: qr_codes.pdf"
puts "Total pages: #{(qr_files.length.to_f / images_per_page).ceil}"
