require "test_helper"

class SeedTest < ActiveSupport::TestCase
  if ENV["SEED_SMOKE_TEST"]
    self.use_transactional_tests = false # don't use fixtures for this test

    setup do
      # ensure that the db is pristine
      ActiveRecord::FixtureSet.reset_cache
      ActiveRecord::Base.connection.disable_referential_integrity do
        ActiveRecord::Base.connection.tables.each do |table|
          ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
          # Reset SQLite sequences
          ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name='#{table}'")
        end
      end

      Rails.application.load_tasks
      Rake::Task["db:environment:set"].reenable
      Rake::Task["db:schema:load"].invoke
    end

    test "seed:all runs successfully" do
      assert_nothing_raised do
        Rake::Task["db:seed:all"].invoke
      end

      # ensure that all talks have a date
      assert_equal Talk.where(date: nil).count, 0

      # Ensuring idempotency
      assert_no_difference "Talk.maximum(:created_at)" do
        Rake::Task["db:seed:all"].reenable
        Rake::Task["db:seed:all"].invoke
      end

      static_video_ids = Static::Video.pluck(:video_id)
      talk_video_ids = Talk.all.pluck(:video_id)
      duplicate_ids = static_video_ids.tally.select { |_, count| count > 1 }
      assert User.speakers.count >= 3000

      assert_equal({}, duplicate_ids)

      not_created_videos_id = static_video_ids - talk_video_ids
      events = Static::Video.where(video_id: not_created_videos_id).map(&:event_name)

      events.tally.each do |event_name, missing_count|
        all_talk_count = Static::Video.where(event_name: event_name).count

        puts "#{event_name} - All: #{all_talk_count}, missing: #{missing_count}"

        if missing_count != all_talk_count
          Static::Video.where(event_name: event_name, video_id: not_created_videos_id).each do |missing_talk|
            puts "Missing talk for #{event_name}: #{missing_talk.raw_title}"
          end
          puts ""
        end
        puts "---"
      end

      assert_equal({}, events.tally)
      assert_equal 0, not_created_videos_id.count
    end
  end
end
