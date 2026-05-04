desc "Download mp4 files for all meta talks"
task download_meta_talks: :environment do |t, args|
  Talk.where(meta_talk: true).each do |meta_talk|
    meta_talk.downloader.download!
  end
end

desc "Download mp4 files for all meta talks with missing thumbnails"
task download_missing_meta_talks: :environment do |t, args|
  meta_talks = Talk.where(meta_talk: true)
  extractable_meta_talks = meta_talks.select { |talk| talk.thumbnails.extractable? }
  missing_talks = extractable_meta_talks.reject { |talk| talk.thumbnails.extracted? }
  missing_talks_without_downloads = missing_talks.reject { |talk| talk.downloader.downloaded? }

  puts "Found #{missing_talks_without_downloads.size} missing talks without downloaded videos."

  missing_talks_without_downloads.each do |talk|
    talk.downloader.download!
  end
end
