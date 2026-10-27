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

      assert_equal Talk.where(date: nil).count, 0

      static_video_ids = Static::Talk.top_level.pluck(:video_id)
      talk_video_ids = Talk.all.pluck(:video_id)
      duplicate_ids = Static::Talk.top_level.group_by(&:video_id).reject { |_, talks| talks.one? || talks.all? { |talk| talk["start_cue"].present? && talk["end_cue"].present? } }.transform_values(&:size)

      assert User.speakers.count >= 3000

      assert_equal({}, duplicate_ids)

      not_created_videos_id = static_video_ids - talk_video_ids
      missing_talks = Static::Talk.where(video_id: not_created_videos_id).group_by { |talk| talk.event&.slug }

      missing_talks.each do |event_slug, talks|
        all_talk_count = Static::Talk.all.count { |talk| talk.event&.slug == event_slug }

        puts "#{event_slug} - All: #{all_talk_count}, missing: #{talks.size}"

        if talks.size != all_talk_count
          talks.each do |missing_talk|
            puts "Missing talk for #{event_slug}: #{missing_talk.raw_title}"
          end
          puts ""
        end
        puts "---"
      end

      assert_equal({}, missing_talks.transform_values(&:size))
      assert_equal 0, not_created_videos_id.count
    end
  end
end
