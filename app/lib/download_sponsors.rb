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
    puts "Arguments: base_url=#{base_url}, sponsors_url=#{sponsors_url}, html=#{html ? 'provided' : 'not provided'}"

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
      href = a[:href].to_s.downcase
      text = a.text.downcase
      # Must contain 'sponsor' and not be a fragment or empty
      (href.include?("sponsor") || text.include?("sponsor")) &&
        !href.strip.empty? &&
        !href.start_with?("#") &&
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
          'disable-web-security' => true,
          'disable-features' => 'VizDisplayCompositor'
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
        name: {type: "string", description: "Name of the sponsor"},
        badge: {type: "string", description: "Extra badge/tag when this sponsor sponored something besides the tier. Usually something like 'Drinkup Sponsor', 'Climbing Sponsor', 'Hack Space Sponsor', 'Nursery Sponsor', 'Scheduler and Drinkup Sponsor', 'Design Sponsor', 'Party Sponsor', 'Lightning Talks Sponsor' or similar. Leave empty if none applies."},
        website: {type: "string", description: "URL for the sponsor"},
        slug: {type: "string", description: "name without spaces, url-safe, all-lowercase, dasherized"},
        logo_url: {type: "string", description: url ? "Full URL path for logo, if it is a relative path include the #{URI(url).origin} as the host, else keep the original URL" : "Full URL path for logo"}
      },
      required: ["name", "badge", "website", "logo_url", "slug"],
      additionalProperties: false
    }

    tier_schema = {
      type: "object",
      properties: {
        name: {type: "string", description: "Name of the tier"},
        description: {type: "string", description: "sponsor description as written on the website. Leave blank if there is no exact description of this tier."},
        level: {type: "integer", description: "positive integer representing the sponsorship hierarchy where 1 is highest. Always start at 1. Higher numbers indicate lower sponsorship hierarchy."},
        sponsors: {
          type: "array",
          items: sponsor_schema
        }
      },
      required: ["name", "sponsors", "level", "description"],
      additionalProperties: false
    }

    schema = {
      tiers: {type: "array", items: tier_schema}
    }

    puts "Calling ActiveGenie::DataExtractor"
    result = ActiveGenie::DataExtractor.call(html_content, schema)

    validated_result = validate_and_process_data(result)

    save_data_to_file(validated_result, save_file)

    puts "Data extraction and validation completed successfully"
    puts "Found #{validated_result['tiers']&.sum { |tier| tier['sponsors']&.length || 0 } || 0} sponsors across #{validated_result['tiers']&.length || 0} tiers"

    validated_result
  rescue => e
    raise DownloadError, "Failed to extract sponsor data: #{e.message}\n Backtrace: \n #{e.backtrace.join("\n")}"
  end

  # DATA VALIDATION METHODS

  def validate_and_process_data(data)
    puts "Validating and processing extracted data"

    unless data.is_a?(Hash) && data['tiers'].is_a?(Array)
      raise ValidationError, "Invalid data structure: expected Hash with 'tiers' array"
    end

    processed_tiers = data['tiers'].map.with_index do |tier, index|
      process_tier(tier, index)
    end
    processed_tiers.reject! { |tier| tier['sponsors'].empty? }
    processed_tiers.sort_by! { |tier| tier['level'] || Float::INFINITY }

    { 'tiers' => processed_tiers }
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
    puts "Processing tier: #{tier['name'] || "Unnamed tier #{index}"}"

    tier['name'] ||= "Tier #{index + 1}"
    tier['level'] ||= index + 1
    tier['description'] ||= ""
    tier['sponsors'] ||= []

    processed_sponsors = process_sponsors(tier['sponsors'])
    deduplicated_sponsors = deduplicate_sponsors(processed_sponsors)

    {
      'name' => tier['name'],
      'description' => tier['description'],
      'level' => tier['level'],
      'sponsors' => deduplicated_sponsors
    }
  end

  def process_sponsors(sponsors)
    return [] unless sponsors.is_a?(Array)

    sponsors.map do |sponsor|
      next unless sponsor.is_a?(Hash)

      sponsor['name'] ||= "Unknown Sponsor"
      sponsor['badge'] ||= ""
      sponsor['website'] ||= ""
      sponsor['logo_url'] ||= ""
      sponsor['slug'] ||= generate_slug(sponsor['name'])
      sponsor['website'] = validate_url(sponsor['website'])
      sponsor['logo_url'] = validate_url(sponsor['logo_url'])

      sponsor
    end.compact
  end

  def deduplicate_sponsors(sponsors)
    puts "Deduplicating #{sponsors.length} sponsors"

    grouped = sponsors.group_by { |s| s['name'].to_s.downcase.strip }

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

    all_badges = duplicates.map { |s| s['badge'] }.compact.reject(&:empty?)
    merged['badge'] = all_badges.uniq.join(', ') if all_badges.any?

    # Prefer non-empty values
    duplicates.each do |duplicate|
      merged['website'] = duplicate['website'] if merged['website'].empty? && !duplicate['website'].empty?
      merged['logo_url'] = duplicate['logo_url'] if merged['logo_url'].empty? && !duplicate['logo_url'].empty?
    end

    merged
  end

  def generate_slug(name)
    return "unknown-sponsor" if name.blank?

    name.to_s
      .downcase
      .gsub(/[^a-z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .gsub(/^-|-$/, '')
      .presence || "unknown-sponsor"
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
