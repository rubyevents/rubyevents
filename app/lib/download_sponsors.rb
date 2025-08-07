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

  def download_sponsors(url, save_file:)
    sponsor_page = find_sponsor_page(url)
    p "Page found: #{sponsor_page}"
    sponsor_page = sponsor_page.blank? ? url : sponsor_page
    download_sponsors_data(sponsor_page, save_file:)
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

    sponsor_schema = {
      type: "object",
      properties: {
        name: {type: "string", description: "Name of the sponsor"},
        website: {type: "string", description: "URL for the sponsor"},
        slug: {type: "string", description: "name without spaces"},
        logo_url: {type: "string", description: "Full URL path for logo, if it is a relative include the #{URI(url).origin} as the host, else keep the original URL"}
      },
      required: ["name", "website", "logo_url", "slug"],
      additionalProperties: false
    }

    tier_schema = {
      type: "object",
      properties: {
        name: {type: "string", description: "Name of the tier"},
        description: {type: "string", description: "sponsor description"},
        level: {type: "integer", description: "positive integer representing the sponsorship hierarchy where 1 is highest, always start at 1,  and lower numbers indicate lower sponsorship"},
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

    result = ActiveGenie::DataExtractor.call(session.html, schema)
    File.write(save_file, [result.stringify_keys].to_yaml)
  ensure
    session&.driver&.quit
  end
end
