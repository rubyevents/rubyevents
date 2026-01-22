xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "RubyEvents.org Announcements"
    xml.description "News and updates from RubyEvents.org"
    xml.link announcements_url
    xml.language "en"
    xml.tag! "atom:link", href: feed_announcements_url(format: :rss), rel: "self", type: "application/rss+xml"

    @announcements.each do |announcement|
      xml.item do
        xml.title announcement.title
        xml.description announcement.excerpt
        xml.pubDate announcement.date.to_time.rfc822
        xml.link announcement_url(announcement)
        xml.guid announcement_url(announcement), isPermaLink: true

        if announcement.author.present?
          xml.author announcement.author
        end

        announcement.tags.each do |tag|
          xml.category tag
        end
      end
    end
  end
end
