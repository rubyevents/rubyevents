xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "Ruby Events - Talks Feed"
    xml.link talks_url
    xml.description "Latest talks in the Ruby ecosystem"
    xml.language "en-us"

    @talks.each do |talk|
      xml.item do
        xml.title talk.title
        xml.description talk.description
        xml.pubDate talk.created_at.to_s
        xml.link talk_url(talk)
        xml.guid talk_url(talk)
      end
    end
  end
end
