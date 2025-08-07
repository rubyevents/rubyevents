class GitHubAvatarDownloader
  require "net/http"
  require "uri"
  require "fileutils"
  require "open3"

  # Configuration
  ASSETS_DIR = "app/assets/images/picture_profile"
  GITHUB_AVATAR_SIZE = 400 # Download high quality images

  def initialize
    ensure_directory_exists
  end

  def download_all_avatars
    puts "🚀 Starting GitHub avatar download and conversion..."

    # Get all speakers with GitHub handles
    speakers = Speaker.with_github

    puts "Found #{speakers.count} speakers with GitHub handles"

    speakers.find_each do |speaker|
      puts "\nProcessing: #{speaker.name} (@#{speaker.github})"
      process_speaker_avatar(speaker)
    end

    puts "\n✅ Done! Local avatar images are stored in #{ASSETS_DIR}"
  end

  private

  def ensure_directory_exists
    FileUtils.mkdir_p(ASSETS_DIR)
  end

  def download_image(url, filepath)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    # Follow redirects
    if response.is_a?(Net::HTTPRedirection)
      redirect_uri = URI(response["location"])
      redirect_http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
      redirect_http.use_ssl = (redirect_uri.scheme == "https")
      redirect_http.read_timeout = 30

      redirect_request = Net::HTTP::Get.new(redirect_uri)
      response = redirect_http.request(redirect_request)
    end

    if response.is_a?(Net::HTTPSuccess)
      File.binwrite(filepath, response.body)
      puts "✓ Downloaded: #{File.basename(filepath)}"
      true
    else
      puts "✗ Failed to download: #{url} (Status: #{response.code})"
      false
    end
  rescue => e
    puts "✗ Error downloading #{url}: #{e.message}"
    false
  end

  def convert_to_webp(input_path, output_path)
    # Check if ImageMagick is available
    cmd = "which convert"
    system(cmd, out: File::NULL, err: File::NULL)

    unless $?.success?
      puts "✗ ImageMagick not found. Please install ImageMagick to convert images to WebP."
      puts "   On macOS: brew install imagemagick"
      puts "   On Ubuntu: sudo apt-get install imagemagick"
      return false
    end

    # Convert to WebP using ImageMagick
    cmd = "convert '#{input_path}' -quality 85 '#{output_path}'"
    _, stderr, status = Open3.capture3(cmd)

    if status.success?
      puts "✓ Converted to WebP: #{File.basename(output_path)}"
      true
    else
      puts "✗ Failed to convert to WebP: #{stderr}"
      false
    end
  end

  def process_speaker_avatar(speaker)
    return unless speaker.github.present?

    github_handle = speaker.github.downcase
    temp_file = File.join(ASSETS_DIR, "#{github_handle}.png")
    webp_file = File.join(ASSETS_DIR, "#{github_handle}.webp")

    # Skip if WebP file already exists
    if File.exist?(webp_file)
      puts "⏭  Skipping #{github_handle} (WebP already exists)"
      return
    end

    # Get GitHub avatar URL
    avatar_url = speaker.github_avatar_url(size: GITHUB_AVATAR_SIZE)

    # Download the image
    if download_image(avatar_url, temp_file)
      # Convert to WebP
      if convert_to_webp(temp_file, webp_file)
        # Clean up temporary PNG file
        File.delete(temp_file) if File.exist?(temp_file)
      else
        # If conversion fails, keep the PNG file
        puts "⚠  Keeping PNG file for #{github_handle} (conversion failed)"
      end
    end
  end
end
