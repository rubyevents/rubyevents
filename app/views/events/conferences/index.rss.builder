xml.instruct! :xml, version: "1.0"
xml.rss :version => "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "Upcoming Ruby Conferences – RubyEvents.org"
    xml.link events_url
    xml.description "Ruby conferences published one calendar month before they begin."
    xml.tag! "atom:link", href: conferences_url(format: :rss), rel: "self", type: "application/rss+xml"
    xml.language "en"

    @events.each do |event|
      xml.item do
        title = event.static_metadata.cancelled? ? "#{event.name} (Cancelled)" : event.name
        details = [event.formatted_dates, event.static_metadata.location].compact_blank.join(" · ")

        xml.title title
        xml.description [details, event.description.strip].compact_blank.join("\n\n")
        xml.pubDate (event.start_date - 1.month).to_time.rfc822
        xml.link event_url(event)
        xml.guid event_url(event), isPermaLink: true
      end
    end
  end
end
