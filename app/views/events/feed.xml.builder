xml.instruct! :xml, version: "1.0", encoding: "UTF-8"

xml.feed(xmlns: "http://www.w3.org/2005/Atom") do
  xml.title "Ruby Events - Events Feed", type: "text", "xml:lang": "en"
  xml.updated Time.now.utc.iso8601
  xml.id "https://rubyevents/events/feed.xml"

  @events.each do |event|
    xml.entry do
      xml.published event.date.to_time.utc.iso8601
      xml.title event.name
      xml.id event_url(event)
      xml.link event_url(event)

      html_content = <<~HTML
        <div class="list-item #{event.name}">
          <dt><a href="#{event_url(event)}">#{event.name}</a></dt>
          <dd>
            <ul>
              <li>#{event.date.year}</li>
              <li>#{event.city}</li>
              <li>#{event.organisation.name}</li>
            </ul>
          </dd>
        </div>
      HTML

      xml.content type: "html" do
        xml.cdata! html_content.strip
      end
    end
  end
end
