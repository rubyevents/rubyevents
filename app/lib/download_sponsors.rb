require "yaml"
require "uri"
require "capybara"
require "capybara/cuprite"

class DownloadSponsors
  def initialize
    Capybara.register_driver(:cuprite_scraper) do |app|
      Capybara::Cuprite::Driver.new(app, window_size: [1200, 800], timeout: 20)
    end
    @session = Capybara::Session.new(:cuprite_scraper)
  end

  attr_reader :session

  def download_sponsors(save_file:, base_url: nil, sponsors_url: nil, html: nil)
    provided_args = [base_url, sponsors_url, html].compact

    raise ArgumentError, "Exactly one of base_url, sponsors_url, or html must be provided" if provided_args.length != 1

    if base_url
      sponsor_page = find_sponsor_page(base_url)
      p "Page found: #{sponsor_page}"
      sponsor_page = sponsor_page.blank? ? base_url : sponsor_page
      download_sponsors_data(sponsor_page, save_file:)
    elsif sponsors_url
      download_sponsors_data(sponsors_url, save_file:)
    elsif html
      download_sponsors_data_from_html(html, save_file:)
    end
  end

  def find_sponsor_page(url)
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
    sponsor_link ? URI.join(url, sponsor_link[:href]).to_s : nil
  end

  # Finds and returns all sponsor page links (hrefs) for a given URL using Capybara + Cuprite
  # Returns an array of unique links (absolute URLs)
  def download_sponsors_data(url, save_file:)
    session.visit(url)
    session.driver.wait_for_network_idle
    extract_and_save_sponsors_data(session.html, save_file, url)
  ensure
    session&.driver&.quit
  end

  def download_sponsors_data_from_html(html_content, save_file:)
    extract_and_save_sponsors_data(html_content, save_file)
  end

  private

  def extract_and_save_sponsors_data(html_content, save_file, url = nil)
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

    result = ActiveGenie::DataExtractor.call(html_content, schema)
    File.write(save_file, [result.stringify_keys].to_yaml)
  end
end
