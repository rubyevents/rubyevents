# frozen_string_literal: true

require "net/http"
require "nokogiri"

module Static
  class Organization
    # What the public site knows about organizations: the index at /organizations and every organization page.
    # `organizations_file:extract` uses it to keep production's grouping, slugs and names when it builds
    # data/organizations.yml. `organizations_file:snapshot` writes it; the JSON is only a build input.
    class Snapshot
      DEFAULT_BASE_URL = "https://www.rubyevents.org"
      DEFAULT_PATH = Rails.root.join("lib/tasks/organizations_file/production_snapshot.json")
      USER_AGENT = "rubyevents organizations_file:snapshot (+https://github.com/rubyevents/rubyevents)"

      Page = Data.define(:status, :body)

      attr_reader :organizations, :aliases, :unknown, :crawled_at, :base_url

      def self.load(path = DEFAULT_PATH)
        return nil unless File.exist?(path)

        data = JSON.parse(File.read(path))

        new(
          organizations: data.fetch("organizations", {}),
          aliases: data.fetch("aliases", {}),
          unknown: data.fetch("unknown", []),
          crawled_at: data["crawled_at"],
          base_url: data["base_url"]
        )
      end

      # Crawls the index and one page per organization, then checks every `slugs` entry the index doesn't list.
      def self.crawl(slugs: [], base_url: DEFAULT_BASE_URL, delay: 0.3, fetcher: nil, log: $stdout)
        fetcher ||= method(:fetch).to_proc.curry[base_url]
        index = parse_index(fetcher.call("/organizations").body)
        log.puts "Index lists #{index.size} organizations"

        organizations = {}
        index.each_with_index do |(slug, name), position|
          page = fetcher.call("/organizations/#{slug}")
          organizations[slug] = parse_organization(page.body).merge("name" => name)
          log.print "\rCrawled #{position + 1}/#{index.size} organization pages"
          sleep(delay)
        end
        log.puts

        aliases = {}
        unknown = []
        names_to_slugs = organizations.to_h { |slug, organization| [organization["name"].to_s.downcase, slug] }
        missing = slugs.map(&:to_s).uniq.sort - organizations.keys

        missing.each_with_index do |slug, position|
          page = fetcher.call("/organizations/#{slug}")

          if page.status == 200
            name = parse_organization(page.body)["name"]
            target = names_to_slugs[name.to_s.downcase]
            target ? (aliases[slug] = target) : unknown << slug
          else
            unknown << slug
          end

          log.print "\rChecked #{position + 1}/#{missing.size} slugs missing from the index"
          sleep(delay)
        end
        log.puts if missing.any?

        new(organizations: organizations, aliases: aliases, unknown: unknown.sort, crawled_at: Time.now.utc.iso8601, base_url: base_url)
      end

      def self.fetch(base_url, path)
        uri = URI.join(base_url, path)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
          http.request(Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => "text/html"))
        end

        Page.new(status: response.code.to_i, body: response.body.to_s)
      end

      # [[slug, name], ...] from the index page, which lists every organization once with a logo and its name
      def self.parse_index(html)
        document = Nokogiri::HTML(html)

        document.css('a[id^="organization_"][href^="/organizations/"]').filter_map do |link|
          slug = link["href"].to_s.delete_prefix("/organizations/").split(%r{[/?#]}).first
          name = link.at_css(".line-clamp-1")&.text&.strip
          name = link.at_css("img[alt$=' Logo']")&.[]("alt")&.delete_suffix(" Logo")&.strip if name.blank?

          [slug, name] if slug.present? && name.present?
        end.uniq(&:first)
      end

      # The fields an organization page shows, and the events it links to
      def self.parse_organization(html)
        document = Nokogiri::HTML(html)
        header = document.at_css("h1")
        name = header&.text&.strip

        logo = document.at_css("img[alt$=' Logo']")
        logo_url = logo&.[]("src")
        logo_background = logo&.ancestors("div")&.map { |node| node["class"].to_s[/\bbg-(white|black|transparent)\b/, 1] }&.compact&.first

        # The header renders the website with `external_link_to`, which sets rel="noopener noreferrer"; footer links don't
        website = document.css("a[href^='http'][rel~='noreferrer']").map { |link| link["href"] }.find do |href|
          host = begin
            URI.parse(href).host.to_s
          rescue
            ""
          end
          host.present? && !host.end_with?("rubyevents.org") && !host.end_with?("rubyvideo.dev")
        end

        {
          "name" => name,
          "website" => website,
          "logo_url" => logo_url&.start_with?("http") ? logo_url : nil,
          "logo_background" => logo_background,
          "main_location" => document.at_css("h3.text-\\[\\#636B74\\]")&.text&.strip.presence,
          "description" => document.at_css("p.mt-6.max-w-\\[700px\\]")&.text&.strip.presence,
          "events" => document.css("a[href^='/events/']").map { |link| link["href"].delete_prefix("/events/").split(%r{[/?#]}).first }.compact_blank.uniq.sort
        }
      end

      def initialize(organizations:, aliases: {}, unknown: [], crawled_at: nil, base_url: nil)
        @organizations = organizations
        @aliases = aliases
        @unknown = unknown
        @crawled_at = crawled_at
        @base_url = base_url
      end

      def write(path = DEFAULT_PATH)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.pretty_generate(to_h) + "\n")

        path
      end

      def to_h
        {
          "crawled_at" => crawled_at,
          "base_url" => base_url,
          "organizations" => organizations.sort.to_h,
          "aliases" => aliases.sort.to_h,
          "unknown" => unknown.sort
        }
      end

      def organization(slug)
        organizations[slug.to_s]
      end

      # The production slug a YAML slug resolves to directly: itself, or the organization an alias points to
      def canonical_slug(slug)
        slug = slug.to_s
        return slug if organizations.key?(slug)

        aliases[slug]
      end

      def slug_by_name(name)
        names_index[name.to_s.strip.downcase]
      end

      # Production organizations whose page lists every one of `event_slugs`
      def slugs_covering_events(event_slugs)
        event_slugs = event_slugs.to_a
        return [] if event_slugs.empty?

        organizations.filter_map { |slug, organization| slug if (event_slugs - Array(organization["events"])).empty? }
      end

      private

      def names_index
        @names_index ||= organizations.each_with_object({}) { |(slug, organization), index| index[organization["name"].to_s.strip.downcase] ||= slug }
      end
    end
  end
end
