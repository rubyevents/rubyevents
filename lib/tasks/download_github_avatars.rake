namespace :speakers do
  desc "Download GitHub profile pictures and convert to WebP format"
  task download_avatars: :environment do
    downloader = GitHubAvatarDownloader.new
    downloader.download_all_avatars
  end
end
