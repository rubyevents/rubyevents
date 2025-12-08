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
      playlist = Event.preload(:series).find_by(name: page["name"])

      if playlist
        page["name"] == conference_name || playlist.slug == conference_name
      else
        page["name"] == conference_name
      end
    }
  end

  conference_pages.each do |id, page|
    artboard_exports = page["artboards"].select { |id, artboard|
      artboard["name"].in?(["card", "featured", "avatar", "banner", "poster"]) ||
        artboard["name"].downcase.start_with?("sticker")
    }
    event = Event.includes(:series).find_by(name: page["name"])

    next if event.nil?

    item_ids = artboard_exports.keys.join(",")
    target_directory = Rails.root.join("app", "assets", "images", "events", event.series.slug, event.slug)

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
    artboard_exports = page["artboards"].select { |id, artboard| artboard["name"].downcase.start_with?("sticker") }
    event = Event.includes(:series).find_by(name: page["name"])

    next if event.nil?
    next if artboard_exports.keys.empty?

    item_ids = artboard_exports.keys.join(",")
    target_directory = Rails.root.join("app", "assets", "images", "events", event.series.slug, event.slug)

    Command.run "#{sketchtool} export artboards #{sketch_file} --items=#{item_ids} --output=#{target_directory} --save-for-web=YES --formats=webp"
  end
end

desc "Export Stamp assets"
task :export_stamps, [:country_code] => :environment do |t, args|
  sketchtool = "/Applications/Sketch.app/Contents/Resources/sketchtool/bin/sketchtool"
  sketch_file = ENV.fetch("STAMPS_SKETCH_FILE", Rails.root.join("stamps.sketch"))

  response = JSON.parse(Command.run("#{sketchtool} metadata document #{sketch_file}"))

  pages = response["pagesAndArtboards"].select { |_id, page| page["artboards"].any? }
  target_directory = Rails.root.join("app", "assets", "images", "stamps")

  FileUtils.mkdir_p(target_directory) unless File.directory?(target_directory)

  exported_count = 0

  pages.each do |_page_id, page|
    page["artboards"].each do |artboard_id, artboard|
      artboard_name = artboard["name"]

      if artboard_name.downcase == "ignore"
        puts "Skipping artboard '#{artboard_name}' - marked as ignore"
        next
      end

      if args[:country_code]
        next unless artboard_name.upcase == args[:country_code].upcase
      end

      stamp_filename = artboard_name.downcase

      Command.run "#{sketchtool} export artboards #{sketch_file} --items=#{artboard_id} --output=#{target_directory} --save-for-web=YES --formats=webp --use-id-for-name=NO"

      exported_file = Dir.glob(File.join(target_directory, "#{artboard_name}.webp")).first ||
        Dir.glob(File.join(target_directory, "*.webp")).max_by { |f| File.mtime(f) }

      if exported_file && File.exist?(exported_file)
        new_filename = File.join(target_directory, "#{stamp_filename}.webp")

        if exported_file != new_filename
          FileUtils.mv(exported_file, new_filename, force: true)
          puts "Exported stamp '#{artboard_name}' → #{stamp_filename}.webp"
        else
          puts "Exported stamp '#{artboard_name}'"
        end
        exported_count += 1
      end
    end
  end

  if args[:country_code] && exported_count == 0
    puts "No stamp found for country code '#{args[:country_code]}'"
  else
    puts "Exported #{exported_count} stamp(s)"
  end
end
