desc "Export Conference assets"
task :export_assets, [:conference_name] => :environment do |t, args|
  sketchtool = "/Applications/Sketch.app/Contents/Resources/sketchtool/bin/sketchtool"
  sketch_file = ENV.fetch("SKETCH_FILE", Rails.root.join("RubyEvents.sketch"))

  response = JSON.parse(Command.run("#{sketchtool} metadata document #{sketch_file}"))

  pages = response["pagesAndArtboards"]

  conference_pages = pages.select { |_id, page|
    page["artboards"].any? # && Static::Playlist.where(title: page["name"]).any?
  }

  if (conference_name = args[:conference_name])
    conference_pages = conference_pages.select { |_id, page|
      playlist = Event.preload(:organisation).find_by(name: page["name"])

      if playlist
        page["name"] == conference_name || playlist.slug == conference_name
      else
        page["name"] == conference_name
      end
    }
  end

  conference_pages.each do |id, page|
    artboard_exports = page["artboards"].select { |id, artboard| artboard["name"].in?(["card", "featured", "avatar", "banner", "poster", "sticker"]) }
    event = Event.includes(:organisation).find_by(name: page["name"])

    next if event.nil?

    item_ids = artboard_exports.keys.join(",")
    target_directory = Rails.root.join("app", "assets", "images", "events", event.organisation.slug, event.slug)

    Command.run "#{sketchtool} export artboards #{sketch_file} --items=#{item_ids} --output=#{target_directory} --save-for-web=YES --formats=webp"
  end
end

desc "Export Sticker assets"
task export_stickers: :environment do
  sketchtool = "/Applications/Sketch.app/Contents/Resources/sketchtool/bin/sketchtool"
  sketch_file = ENV.fetch("SKETCH_FILE", Rails.root.join("RubyEvents.sketch"))

  response = JSON.parse(Command.run("#{sketchtool} metadata document #{sketch_file}"))

  pages = response["pagesAndArtboards"].select { |_id, page| page["artboards"].any? }

  pages.each do |id, page|
    artboard_exports = page["artboards"].select { |id, artboard| artboard["name"].in?(["sticker"]) }
    event = Event.includes(:organisation).find_by(name: page["name"])

    next if event.nil?
    next if artboard_exports.keys.empty?

    item_ids = artboard_exports.keys.join(",")
    target_directory = Rails.root.join("app", "assets", "images", "events", event.organisation.slug, event.slug)

    Command.run "#{sketchtool} export artboards #{sketch_file} --items=#{item_ids} --output=#{target_directory} --save-for-web=YES --formats=webp"
  end
end
