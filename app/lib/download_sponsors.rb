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

    result = ActiveGenie::DataExtractor.call(html_content, schema)
    File.write(save_file, [result.stringify_keys].to_yaml)
  end
end
