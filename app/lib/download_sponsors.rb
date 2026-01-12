require "yaml"
require "uri"
require "capybara"
require "capybara/cuprite"
require "fileutils"

class DownloadSponsors
  class DownloadError < StandardError; end

  class ValidationError < StandardError; end

  MAX_RETRIES = 3
  RETRY_DELAY = 2
  NETWORK_TIMEOUT = 30

  def initialize
    setup_capybara
    @retry_count = 0
  end

  attr_reader :session

  def download_sponsors(save_file:, base_url: nil, sponsors_url: nil, html: nil)
    provided_args = [base_url, sponsors_url, html].compact

    raise ArgumentError, "Exactly one of base_url, sponsors_url, or html must be provided" if provided_args.length != 1

    puts "Starting sponsor download process"
    puts "Save file: #{save_file}"
    puts "Arguments: base_url=#{base_url}, sponsors_url=#{sponsors_url}, html=#{html ? "provided" : "not provided"}"

    begin
      if base_url
        sponsor_page = find_sponsor_page_with_retry(base_url)
        puts "Sponsor page found: #{sponsor_page}"
        sponsor_page = sponsor_page.blank? ? base_url : sponsor_page
        download_sponsors_data_with_retry(sponsor_page, save_file:)
      elsif sponsors_url
        download_sponsors_data_with_retry(sponsors_url, save_file:)
      elsif html
        download_sponsors_data_from_html(html, save_file:)
      end

      puts "Sponsor download completed successfully"
    rescue => e
      raise DownloadError, "Failed to download sponsors: #{e.message}\n Backtrace: \n #{e.backtrace.join("\n")}"
    end
  end

  def find_sponsor_page_with_retry(url)
    with_retry("finding sponsor page") do
      find_sponsor_page(url)
    end
  end

  def download_sponsors_data_with_retry(url, save_file:)
    with_retry("downloading sponsor data") do
      download_sponsors_data(url, save_file:)
    end
  end

  def download_sponsors_data_from_html(html_content, save_file:)
    puts "Processing sponsor data from provided HTML (#{html_content.length} characters)"
    extract_and_save_sponsors_data(html_content, save_file)
  end

  private

  # MAIN METHODS

  def find_sponsor_page(url)
    puts "Searching for sponsor page at: #{url}"

    session.visit(url)
    session.driver.wait_for_network_idle

    # Heuristic: look for links with 'sponsor' in href or text, but not logo/image links
    sponsor_link = session.all("a[href]").find do |a|
      original_href = a[:href].to_s
      href = original_href.downcase
      text = a.text.downcase

      # Check if this is a fragment link by looking at the URI fragment
      uri = URI.parse(original_href)
      base_uri = URI.parse(url)

      # A fragment link has a fragment and points to the same page (same host and path)
      is_fragment = uri.fragment &&
        uri.host == base_uri.host &&
        (uri.path == "/" || uri.path == base_uri.path)

      # Must contain 'sponsor' and not be a fragment or empty
      (href.include?("sponsor") || text.include?("sponsor")) &&
        !original_href.strip.empty? &&
        !is_fragment &&
        # Avoid links that are just logo images
        !a.first("img", minimum: 0)
    end

    if sponsor_link
      result = URI.join(url, sponsor_link[:href]).to_s
      puts "Found sponsor link: #{result}"
      result
    else
      puts "WARNING: No sponsor link found on page"
      nil
    end
  rescue => e
    raise DownloadError, "Failed to find sponsor page: #{e.message}\n Backtrace: \n #{e.backtrace.join("\n")}"
  end

  # Finds and returns all sponsor page links (hrefs) for a given URL using Capybara + Cuprite
  # Returns an array of unique links (absolute URLs)
  def download_sponsors_data(url, save_file:)
    puts "Downloading sponsor data from: #{url}"

    session.visit(url)
    session.driver.wait_for_network_idle
    html_content = session.html

    puts "Successfully retrieved HTML content (#{html_content.length} characters)"
    extract_and_save_sponsors_data(html_content, save_file, url)
  rescue => e
    raise DownloadError, "Failed to download sponsor data: #{e.message}\n Backtrace: \n #{e.backtrace.join("\n")}"
  ensure
    cleanup_session
  end

  # UTILITY METHODS

  def with_retry(operation_name)
    @retry_count = 0
    begin
      yield
    rescue => e
      @retry_count += 1
      if @retry_count <= MAX_RETRIES
        puts "WARNING: Attempt #{@retry_count} failed for #{operation_name}: #{e.message}"
        puts "Retrying in #{RETRY_DELAY} seconds..."
        sleep(RETRY_DELAY)
        retry
      else
        puts "ERROR: All #{MAX_RETRIES} attempts failed for #{operation_name}"
        raise e
      end
    end
  end

  def setup_capybara
    Capybara.register_driver(:cuprite_scraper) do |app|
      Capybara::Cuprite::Driver.new(
        app,
        window_size: [1200, 800],
        timeout: NETWORK_TIMEOUT,
        browser_options: {
          "disable-web-security" => true,
          "disable-features" => "VizDisplayCompositor"
        }
      )
    end
    @session = Capybara::Session.new(:cuprite_scraper)
  rescue => e
    raise DownloadError, "Failed to setup web scraper: #{e.message}\n Backtrace: \n #{e.backtrace.join("\n")}"
  end

  def cleanup_session
    if session&.driver
      session.driver.quit
      puts "Session cleaned up"
    end
  rescue => e
    puts "WARNING: Error during session cleanup: #{e.message}"
  end

  # DATA EXTRACTION METHODS

  def extract_and_save_sponsors_data(html_content, save_file, url = nil)
    puts "Extracting sponsor data from HTML"

    sponsor_schema = {
      type: "object",
      properties: {
        name: {
          type: "string",
          description: "Official company or organization name as displayed on the website. Extract the exact name without abbreviations unless that's how it's presented."
        },
        badge: {
          type: "string",
          description: "Special sponsorship role or additional service beyond the tier level. Common examples include: 'Drinkup Sponsor', 'Climbing Sponsor', 'Hack Space Sponsor', 'Nursery Sponsor', 'Party Sponsor', 'Lightning Talks Sponsor', 'Coffee Sponsor', 'Lunch Sponsor', 'Breakfast Sponsor', 'Networking Sponsor', 'Swag Sponsor', 'Livestream Sponsor', 'Accessibility Sponsor', 'Diversity Sponsor', 'Travel Sponsor', 'Venue Sponsor', 'WiFi Sponsor', 'Welcome Reception Sponsor'. Leave empty string if no special badge is mentioned."
        },
        website: {
          type: "string",
          description: "Complete URL to the sponsor's main website. Must be a valid HTTP/HTTPS URL. If only a domain is provided, prepend with 'https://'. Do not include tracking parameters or fragments."
        },
        slug: {
          type: "string",
          description: "URL-safe identifier derived from the company name. Convert to lowercase, replace spaces and special characters with hyphens, remove consecutive hyphens. Examples: 'Evil Martians' -> 'evil-martians', 'AppSignal' -> 'appsignal', '84codes' -> '84codes'"
        },
        logo_url: {
          type: "string",
          description: url ? "Complete URL path to the sponsor's logo image. If the logo path is relative (starts with / or ./ or just a filename), prepend with '#{URI(url).origin}'. Ensure the URL points to an actual image file (png, jpg, jpeg, svg, webp). Avoid placeholder or broken image URLs." : "Complete URL path to the sponsor's logo image. Must be a valid HTTP/HTTPS URL pointing to an image file."
        }
      },
      required: ["name", "badge", "website", "logo_url", "slug"],
      additionalProperties: false
    }

    tier_schema = {
      type: "object",
      properties: {
        name: {
          type: "string",
          description: "Exact name of the sponsorship tier as displayed on the website. Common tier names include: 'Platinum', 'Gold', 'Silver', 'Bronze', 'Diamond', 'Ruby', 'Emerald', 'Sapphire', 'Premier', 'Principal', 'Supporting', 'Community', 'Partner', 'Friend', 'Startup', 'Individual', 'Media Partner', 'Travel Sponsor', 'Diversity Sponsor'."
        },
        description: {
          type: "string",
          description: "Official description of this sponsorship tier as written on the website. Include benefits, perks, or explanatory text if provided. If no specific description exists for this tier, provide an empty string. Do not invent descriptions."
        },
        level: {
          type: "integer",
          description: "Numeric hierarchy level where 1 is the highest/most premium tier. Assign based on visual prominence, price indicators, or explicit hierarchy. Common patterns: Platinum/Diamond=1, Gold=2, Silver=3, Bronze=4, Community/Supporting=higher numbers. If unclear, estimate based on sponsor logos size and placement."
        },
        sponsors: {
          type: "array",
          items: sponsor_schema,
          description: "Array of all sponsors in this tier. Each sponsor should be a complete object with all required fields."
        }
      },
      required: ["name", "sponsors", "level", "description"],
      additionalProperties: false
    }

    schema = {
      type: "object",
      properties: {
        tiers: {
          type: "array",
          items: tier_schema,
          description: "Complete list of all sponsorship tiers found on the page, ordered by hierarchy level (1=highest). Look for sponsor sections, partner sections, and supporter sections. Include all visible sponsor information."
        }
      },
      required: ["tiers"],
      additionalProperties: false
    }

    puts "Calling ActiveGenie::DataExtractor"
    result = ActiveGenie::DataExtractor.call(html_content, schema)

    validated_result = validate_and_process_data(result)

    save_data_to_file(validated_result, save_file)

    puts "Data extraction and validation completed successfully"
    puts "Found #{validated_result["tiers"]&.sum { |tier| tier["sponsors"]&.length || 0 } || 0} sponsors across #{validated_result["tiers"]&.length || 0} tiers"

    validated_result
  rescue => e
    raise DownloadError, "Failed to extract sponsor data: #{e.message}\n Backtrace: \n #{e.backtrace.join("\n")}"
  end

  # DATA VALIDATION METHODS

  def validate_and_process_data(data)
    puts "Validating and processing extracted data"

    unless data.is_a?(Hash) && data["tiers"].is_a?(Array)
      raise ValidationError, "Invalid data structure: expected Hash with 'tiers' array"
    end

    processed_tiers = data["tiers"].map.with_index do |tier, index|
      process_tier(tier, index)
    end
    processed_tiers.reject! { |tier| tier["sponsors"].empty? }
    processed_tiers.sort_by! { |tier| tier["level"] || Float::INFINITY }

    {"tiers" => processed_tiers}
  rescue => e
    raise ValidationError, "Data validation failed: #{e.message}\n Backtrace: \n #{e.backtrace.join("\n")}"
  end

  def validate_url(url)
    return "" if url.blank?

    begin
      uri = URI(url)
      if uri.scheme.nil?
        "https://#{url}"
      else
        url
      end
    rescue URI::InvalidURIError
      puts "WARNING: Invalid URL: #{url}"
      ""
    end
  end

  # DATA PROCESSING METHODS

  def process_tier(tier, index)
    puts "Processing tier: #{tier["name"] || "Unnamed tier #{index}"}"

    tier["name"] ||= "Tier #{index + 1}"
    tier["level"] ||= index + 1
    tier["description"] ||= ""
    tier["sponsors"] ||= []

    processed_sponsors = process_sponsors(tier["sponsors"])
    deduplicated_sponsors = deduplicate_sponsors(processed_sponsors)

    {
      "name" => tier["name"],
      "description" => tier["description"],
      "level" => tier["level"],
      "sponsors" => deduplicated_sponsors
    }
  end

  def process_sponsors(sponsors)
    return [] unless sponsors.is_a?(Array)

    sponsors.map do |sponsor|
      next unless sponsor.is_a?(Hash)

      sponsor["name"] ||= "Unknown Sponsor"
      sponsor["badge"] ||= ""
      sponsor["website"] ||= ""
      sponsor["logo_url"] ||= ""
      sponsor["slug"] ||= generate_slug(sponsor["name"])
      sponsor["website"] = validate_url(sponsor["website"])
      sponsor["logo_url"] = validate_url(sponsor["logo_url"])

      sponsor
    end.compact
  end

  def deduplicate_sponsors(sponsors)
    puts "Deduplicating #{sponsors.length} sponsors"

    grouped = sponsors.group_by { |s| s["name"].to_s.downcase.strip }

    merged_sponsors = grouped.map do |name, duplicates|
      if duplicates.length == 1
        duplicates.first
      else
        puts "Found #{duplicates.length} duplicates for sponsor: #{name}"
        merge_sponsor_duplicates(duplicates)
      end
    end

    puts "After deduplication: #{merged_sponsors.length} unique sponsors"
    merged_sponsors
  end

  def merge_sponsor_duplicates(duplicates)
    merged = duplicates.first.dup

    all_badges = duplicates.map { |s| s["badge"] }.compact.reject(&:empty?)
    merged["badge"] = all_badges.uniq.join(", ") if all_badges.any?

    # Prefer non-empty values
    duplicates.each do |duplicate|
      merged["website"] = duplicate["website"] if merged["website"].empty? && !duplicate["website"].empty?
      merged["logo_url"] = duplicate["logo_url"] if merged["logo_url"].empty? && !duplicate["logo_url"].empty?
    end

    merged
  end

  def generate_slug(name)
    return "unknown-sponsor" if name.blank?

    slug = name.parameterize
    slug.presence || "unknown-sponsor"
  end

  # DATA SAVING METHODS

  def save_data_to_file(data, save_file)
    puts "Saving data to file: #{save_file}"

    FileUtils.mkdir_p(File.dirname(save_file))

    yaml_content = [data.stringify_keys].to_yaml

    temp_file = "#{save_file}.tmp"
    File.write(temp_file, yaml_content)
    File.rename(temp_file, save_file)

    puts "Data saved successfully (#{yaml_content.length} characters)"
  rescue => e
    raise DownloadError, "Failed to save data: #{e.message}\n Backtrace: \n #{e.backtrace.join("\n")}"
  end
end
