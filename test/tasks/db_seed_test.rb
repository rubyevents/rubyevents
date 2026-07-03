require "test_helper"

class DbSeedTest < ActiveSupport::TestCase
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

    test "db:seed runs successfully" do
      assert_nothing_raised do
        Rake::Task["db:seed"].invoke
      end

      # ensure that all talks have a date
      assert_equal Talk.where(date: nil).count, 0

      # Ensuring idempotency
      assert_no_difference "Talk.maximum(:created_at)" do
        Rake::Task["db:seed"].reenable
        Rake::Task["db:seed"].invoke
      end

      static_video_ids = Static::Video.pluck(:video_id)
      duplicate_ids = static_video_ids.tally.select { |_, count| count > 1 }

      assert User.speakers.count >= 3000
      assert Talk.count >= 200
      assert Event.count >= 10
      assert_equal({}, duplicate_ids)
    end
  end
end
