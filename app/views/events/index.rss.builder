xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "Events"
    xml.link events_url
    xml.description "Upcoming Ruby Events"
    xml.language "en-us"
    xml.pubDate @events.first.created_at.to_fs(:rfc822) if @events.any?

    @events.each do |event|
      xml.item do
        xml.title event.name
        xml.description event.description
        xml.pubDate event.created_at.to_fs(:rfc822)
        xml.link event_url(event)
        xml.guid event_url(event)
      end
    end
  end
end
