# lib/tasks/update_video_statistics.rake

namespace :update_video_statistics do
  desc "Update view_count and like_count in Talk table"
  task update: :environment do
    client = YouTube::Video.new

    Talk.find_each do |talk|
      stats = client.get_statistics(talk.video_id)
      if stats
        talk.update(
          view_count: stats[:view_count],
          like_count: stats[:like_count]
        )
      else
        puts "Skipping talk with ID: #{talk.id} due to missing stats"
      end
    end

    puts "Updated video statistics for all talks"
  end
end
