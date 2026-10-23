class EventFreshnessJudge < RubyLLM::Judge
  THRESHOLD = 0.7
  WEBSITE_TEXT_LIMIT = 50_000
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"

  AREAS = %i[dates location venue cfp talks schedule sponsors involvements tickets recordings].freeze

  model "gpt-6-luna", provider: :openai

  choice :edition, "Which edition of the event is the website currently about, compared to current_data.event?" do
    this_edition "The website describes the same edition as current_data.event"
    later_edition "The website has moved on to a later edition (e.g. next year's event)"
    earlier_edition "The website still describes an earlier edition"
    unrelated "The website is unavailable, parked, or not about this event"
  end

  probability :dates, "Does the website show event dates that differ from current_data.event start_date/end_date?"
  probability :location, "Does the website show a city or country that differs from current_data.event location?"
  probability :venue, "Does the website name a venue that is missing from or differs from current_data.venue?"
  probability :cfp, "Does the website announce a call for proposals, or CFP dates or a link, missing from or different from current_data.cfps?"
  probability :talks, "Does the website list speakers or talks that are missing from current_data.talks?"
  probability :schedule, "Does the website publish a schedule or agenda while current_data.schedule_present is false?"
  probability :sponsors, "Does the website list sponsors that are missing from current_data.sponsors?"
  probability :involvements, "Does the website name organizers, MCs, or volunteers missing from current_data.involvements?"
  probability :tickets, "Does the website link to a ticket shop that is missing from or differs from current_data.event tickets_url?"
  probability :recordings, "Does the website link to talk recordings or videos that are missing from current_data.talks?"

  def self.check(event, urls: [event.website])
    pages = urls.compact_blank.to_h { |url| [url, fetch_text(url)] }

    judge(input_for(event, pages))
  end

  def self.input_for(event, pages)
    {
      today: Date.current.iso8601,
      current_data: current_data(event),
      website: pages
    }
  end

  def self.current_data(event)
    {
      event: event.to_h.slice("title", "kind", "location", "start_date", "end_date", "website", "tickets_url"),
      venue: event.venue&.to_h&.slice("name", "address"),
      cfps: event.cfps.map(&:to_h),
      talks: event.talks.map { |talk| talk.to_h.slice("title", "speakers", "date", "video_provider") },
      schedule_present: event.schedule.present?,
      sponsors: event.sponsors.flat_map { it.tiers.to_a }.to_h { |tier| [tier.name, tier.sponsors.map { it["name"] }] },
      involvements: event.involvements.map(&:to_h)
    }.compact
  end

  def self.fetch_text(url, redirects: 3)
    response = Net::HTTP.get_response(URI(url), "User-Agent" => USER_AGENT)

    if response.is_a?(Net::HTTPRedirection) && redirects.positive?
      return fetch_text(URI.join(url, response["location"]).to_s, redirects: redirects - 1)
    end

    return "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    document = Nokogiri::HTML(response.body)
    document.css("script, style, noscript, svg, template").remove
    document.xpath("//text()").map(&:text).join(" ").squish.truncate(WEBSITE_TEXT_LIMIT)
  rescue *ApplicationClient::NET_HTTP_ERRORS, SocketError, OpenSSL::SSL::SSLError => e
    "Unreachable: #{e.class}"
  end

  def self.stale_areas(judgment, threshold: THRESHOLD)
    return [] unless judgment.edition.choice == :this_edition

    AREAS.select { |area| judgment.fetch(area).probability >= threshold }
  end
end
