# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module Static
  class DataImporterTest < ActiveSupport::TestCase
    test "routes speakers.yml to Static::Speaker.import_all! and reports success even when it returns nil" do
      called = false
      Static::Speaker.stub(:import_all!, -> { called = true and nil }) do
        assert Static::DataImporter.import("data/speakers.yml")
      end
      assert called
    end

    test "routes topics.yml to Static::Topic.import_all!" do
      called = false
      Static::Topic.stub(:import_all!, -> { called = true }) do
        assert Static::DataImporter.import("data/topics.yml")
      end
      assert called
    end

    test "routes featured_cities.yml to Static::City.import_all!" do
      called = false
      Static::City.stub(:import_all!, -> { called = true }) do
        assert Static::DataImporter.import("data/featured_cities.yml")
      end
      assert called
    end

    test "routes series.yml to EventSeries#import_series!" do
      series = Minitest::Mock.new
      series.expect(:import_series!, true)

      Static::DataImporter.stub(:series_for, series) do
        assert Static::DataImporter.import("data/rubyconf/series.yml")
      end

      series.verify
    end

    test "model_for applies the sibling-file rules for series-level and event-level files" do
      series_involvements = Rails.root.join("data/amsterdam-rb/involvements.yml").to_s
      event_involvements = Rails.root.join("data/rubyconf/rubyconf-2024/involvements.yml").to_s
      nested_series = Rails.root.join("data/rails-girls/rails-girls-bern/series.yml").to_s

      assert_equal Static::SeriesInvolvement, Static::DataImporter.model_for(series_involvements)
      assert_equal Static::Involvement, Static::DataImporter.model_for(event_involvements)
      assert_equal Static::EventSeries, Static::DataImporter.model_for(nested_series)
    end

    test "routes series-level files to the series' import methods" do
      {
        "involvements" => :import_involvements!,
        "sponsors" => :import_sponsors!,
        "cfp" => :import_cfps!
      }.each do |basename, method|
        File.write(Rails.root.join("data/amsterdam-rb/#{basename}.yml"), "--- []\n") unless File.exist?(Rails.root.join("data/amsterdam-rb/#{basename}.yml"))

        record = Object.new
        static_series = Minitest::Mock.new
        static_series.expect(:event_series_record, record)
        static_series.expect(method, true, [record])

        Static::DataImporter.stub(:series_for, static_series) do
          assert Static::DataImporter.import("data/amsterdam-rb/#{basename}.yml")
        end

        static_series.verify
      end
    ensure
      %w[sponsors cfp].each do |basename|
        path = Rails.root.join("data/amsterdam-rb/#{basename}.yml")
        File.delete(path) if File.exist?(path) && File.read(path) == "--- []\n"
      end
    end

    test "routes event.yml and venue.yml to Event#import_event! and applies removed_talk_ids" do
      %w[event venue].each do |basename|
        record = Object.new
        static_event = Minitest::Mock.new
        static_event.expect(:import_event!, record)
        static_event.expect(:destroy_removed_talks!, nil, [record])

        Static::DataImporter.stub(:event_for, static_event) do
          assert Static::DataImporter.import("data/rubyconf/rubyconf-2024/#{basename}.yml")
        end

        static_event.verify
      end
    end

    test "routes per-event child files through with_event" do
      {
        "videos" => :import_videos!,
        "sponsors" => :import_sponsors!,
        "cfp" => :import_cfps!,
        "involvements" => :import_involvements!
      }.each do |basename, method|
        record = Object.new
        static_event = Minitest::Mock.new
        static_event.expect(:slug, "rubyconf-2024")
        static_event.expect(method, true, [record])

        Static::DataImporter.stub(:event_for, static_event) do
          ::Event.stub(:find_by, record) do
            assert Static::DataImporter.import("data/rubyconf/rubyconf-2024/#{basename}.yml")
          end
        end

        static_event.verify
      end
    end

    test "importing a child file auto-imports the event when it is not in the database yet" do
      record = Object.new
      static_event = Minitest::Mock.new
      static_event.expect(:slug, "rubyconf-2024")
      static_event.expect(:import_event!, record)
      static_event.expect(:import_videos!, true, [record])

      Static::DataImporter.stub(:event_for, static_event) do
        ::Event.stub(:find_by, nil) do
          assert Static::DataImporter.import("data/rubyconf/rubyconf-2024/videos.yml")
        end
      end

      static_event.verify
    end

    test "returns false when the event is unknown in the data files" do
      Static::DataImporter.stub(:event_for, nil) do
        assert_equal false, Static::DataImporter.import("data/unknown/unknown-2024/videos.yml")
      end
    end

    test "schedule files are handled as a no-op" do
      assert_equal true, Static::DataImporter.import("data/rubyconf/rubyconf-2024/schedule.yml")
    end

    test "unknown data paths return false" do
      assert_equal false, Static::DataImporter.import("data/rubyconf/rubyconf-2024/unknown.yml")
    end

    test "import accepts absolute paths" do
      called = false
      Static::Speaker.stub(:import_all!, -> { called = true }) do
        Static::DataImporter.import(Rails.root.join("data/speakers.yml").to_s)
      end
      assert called
    end

    test "seed_changed! imports changed files once and skips unchanged ones" do
      relative = "data/tmp_seed_changed_test.yml"
      absolute = Rails.root.join(relative)
      File.write(absolute, "one\n")

      imported = []
      Static::DataImporter.stub(:seed_phases, [[absolute.to_s]]) do
        Static::DataImporter.stub(:import, ->(path, reload: false) {
          imported << path
          true
        }) do
          first = Static::DataImporter.seed_changed!(logger: ->(_) {})
          assert_equal 1, first[:imported]
          assert_equal 0, first[:skipped]

          second = Static::DataImporter.seed_changed!(logger: ->(_) {})
          assert_equal 0, second[:imported]
          assert_equal 1, second[:skipped]
        end
      end

      assert_equal [relative], imported
    ensure
      File.delete(absolute) if File.exist?(absolute)
      ImportedFile.forget!(relative)
    end

    test "seed_changed! reports files the importer cannot route as failed" do
      relative = "data/tmp_seed_unrouted_test.yml"
      absolute = Rails.root.join(relative)
      File.write(absolute, "one\n")

      Static::DataImporter.stub(:seed_phases, [[absolute.to_s]]) do
        Static::DataImporter.stub(:import, ->(_path) { false }) do
          result = Static::DataImporter.seed_changed!(logger: ->(_) {})

          assert_equal [relative], result[:failed]
        end
      end

      assert ImportedFile.changed?(relative)
    ensure
      File.delete(absolute) if File.exist?(absolute)
      ImportedFile.forget!(relative)
    end

    test "seed_changed! reports failed files and retries them on the next run" do
      relative = "data/tmp_seed_failed_test.yml"
      absolute = Rails.root.join(relative)
      File.write(absolute, "one\n")

      Static::DataImporter.stub(:seed_phases, [[absolute.to_s]]) do
        Static::DataImporter.stub(:import, ->(_path, reload: false) { raise "boom" }) do
          first = Static::DataImporter.seed_changed!(logger: ->(_) {})
          assert_equal [relative], first[:failed]
          assert_equal 0, first[:imported]

          second = Static::DataImporter.seed_changed!(logger: ->(_) {})
          assert_equal [relative], second[:failed]
        end
      end

      assert ImportedFile.changed?(relative)
    ensure
      File.delete(absolute) if File.exist?(absolute)
      ImportedFile.forget!(relative)
    end

    test "seed_changed! removes deleted data files and forgets their fingerprints" do
      relative = "data/rubyconf/rubyconf-2099/sponsors.yml"
      ImportedFile.create!(file_path: relative, fingerprint: "stale")
      removed = []

      Static::DataImporter.stub(:seed_phases, []) do
        Static::DataImporter.stub(:remove, ->(path, reload: true) { removed << path }) do
          result = Static::DataImporter.seed_changed!(logger: ->(_) {})

          assert_equal 1, result[:removed]
        end
      end

      assert_equal [relative], removed
      assert_not ImportedFile.exists?(file_path: relative)
    end

    test "seed_changed! keeps the fingerprint of a deleted file when removing it fails" do
      relative = "data/rubyconf/rubyconf-2099/sponsors.yml"
      ImportedFile.create!(file_path: relative, fingerprint: "stale")

      Static::DataImporter.stub(:seed_phases, []) do
        Static::DataImporter.stub(:remove, ->(_path, reload: true) { raise "boom" }) do
          result = Static::DataImporter.seed_changed!(logger: ->(_) {})

          assert_equal [relative], result[:failed]
        end
      end

      assert ImportedFile.exists?(file_path: relative)
    ensure
      ImportedFile.forget!(relative)
    end

    test "remove destroys the records of a deleted per-event file" do
      {
        "sponsors" => :sponsors,
        "cfp" => :cfps,
        "involvements" => :event_involvements
      }.each do |basename, association|
        records = Minitest::Mock.new
        records.expect(:destroy_all, [])
        event = Minitest::Mock.new
        event.expect(:public_send, records, [association])

        ::Event.stub(:find_by, event) do
          assert Static::DataImporter.remove("data/rubyconf/rubyconf-2024/#{basename}.yml")
        end

        records.verify
        event.verify
      end
    end

    test "remove re-imports the event when its venue.yml is deleted" do
      static_event = Minitest::Mock.new
      static_event.expect(:import_event!, Object.new)

      Static::DataImporter.stub(:event_for, static_event) do
        assert Static::DataImporter.remove("data/rubyconf/rubyconf-2024/venue.yml")
      end

      static_event.verify
    end

    test "remove keeps talks, events and series when their file is deleted" do
      ::Event.stub(:find_by, ->(*) { flunk "should not look up the event" }) do
        %w[rubyconf/rubyconf-2024/videos.yml rubyconf/rubyconf-2024/event.yml rubyconf/series.yml rubyconf/rubyconf-2024/schedule.yml speakers.yml].each do |path|
          assert_equal false, Static::DataImporter.remove("data/#{path}")
        end
      end
    end

    test "sync imports only the batch's changed files in one pass without per-file reloads" do
      relative = "data/tmp_sync_batch_test.yml"
      other = "data/tmp_sync_other_test.yml"
      [relative, other].each { |path| File.write(Rails.root.join(path), "one\n") }
      imported = []

      Static::DataImporter.stub(:seed_phases, [[Rails.root.join(other).to_s, Rails.root.join(relative).to_s]]) do
        Static::DataImporter.stub(:import, ->(path, reload: false) {
          imported << [path, reload]
          true
        }) do
          Search::Backend.stub(:reindex_all, -> { flunk "should not reindex everything for a small batch" }) do
            Search::Backend.stub(:reindex_changed_since, ->(_time) {}) do
              Static::DataImporter.sync([relative, relative], logger: ->(_) {})
            end
          end
        end
      end

      assert_equal [[relative, false]], imported
      assert_not ImportedFile.changed?(relative)
      assert ImportedFile.changed?(other)
    ensure
      [relative, other].each do |path|
        File.delete(Rails.root.join(path)) if File.exist?(Rails.root.join(path))
        ImportedFile.forget!(path)
      end
    end

    test "sync removes the batch's deleted files" do
      relative = "data/rubyconf/rubyconf-2099/sponsors.yml"
      other = "data/rubyconf/rubyconf-2099/cfp.yml"
      [relative, other].each { |path| ImportedFile.create!(file_path: path, fingerprint: "stale") }
      removed = []

      Static::DataImporter.stub(:seed_phases, []) do
        Static::DataImporter.stub(:remove, ->(path, reload: true) { removed << [path, reload] }) do
          Static::DataImporter.sync([relative], logger: ->(_) {})
        end
      end

      assert_equal [[relative, false]], removed
      assert_not ImportedFile.exists?(file_path: relative)
      assert ImportedFile.exists?(file_path: other)
    ensure
      ImportedFile.forget!(other)
    end

    test "sync skips per-record indexing for a large batch and reindexes once" do
      paths = (1..(Static::DataImporter::FULL_REINDEX_THRESHOLD + 1)).map { |index| "data/series-#{index}/series.yml" }
      indexing_skipped = nil
      reindexed = 0

      Static::DataImporter.stub(:seed_changed!, ->(only:, logger:) {
        indexing_skipped = Search::Backend.skip_indexing
        assert_equal paths, only
        {imported: 3, removed: 0, skipped: 0, failed: []}
      }) do
        Search::Backend.stub(:reindex_all, -> { reindexed += 1 }) do
          Static::DataImporter.sync(paths, logger: ->(_) {})
        end
      end

      assert indexing_skipped
      assert_equal 1, reindexed
    end

    test "with_indexing_for keeps indexing on for a small seed and only reindexes what changed" do
      started_at = Time.current
      indexing_skipped = nil
      reindexed_since = nil

      Search::Backend.stub(:reindex_all, -> { flunk "should not reindex everything" }) do
        Search::Backend.stub(:reindex_changed_since, ->(time) { reindexed_since = time }) do
          Static::DataImporter.with_indexing_for(Static::DataImporter::FULL_REINDEX_THRESHOLD) do
            indexing_skipped = Search::Backend.skip_indexing
            {imported: 1, removed: 0, skipped: 0, failed: []}
          end
        end
      end

      assert_not indexing_skipped
      assert_operator reindexed_since, :>=, started_at
    end

    test "with_indexing_for reindexes everything once for a forced seed" do
      indexing_skipped = nil
      reindexed = 0

      Search::Backend.stub(:reindex_all, -> { reindexed += 1 }) do
        Search::Backend.stub(:reindex_changed_since, ->(_time) { flunk "should reindex everything" }) do
          Static::DataImporter.with_indexing_for(1, force: true) do
            indexing_skipped = Search::Backend.skip_indexing
            {imported: 1, removed: 0, skipped: 0, failed: []}
          end
        end
      end

      assert indexing_skipped
      assert_equal 1, reindexed
    end

    test "with_indexing_for does not reindex when nothing changed" do
      Search::Backend.stub(:reindex_all, -> { flunk "should not reindex" }) do
        Search::Backend.stub(:reindex_changed_since, ->(_time) { flunk "should not reindex" }) do
          result = Static::DataImporter.with_indexing_for(1) { {imported: 0, removed: 0, skipped: 5, failed: []} }

          assert_equal 5, result[:skipped]
        end
      end
    end

    test "remove destroys the series' records of a deleted series-level file" do
      records = Minitest::Mock.new
      records.expect(:destroy_all, [])
      event_series = Minitest::Mock.new
      event_series.expect(:public_send, records, [:event_involvements])

      ::EventSeries.stub(:find_by, event_series) do
        assert Static::DataImporter.remove("data/amsterdam-rb/involvements.yml")
      end

      records.verify
      event_series.verify
    end

    test "finalize! migrates old talks of touched events and merges old events of their series" do
      calls = []
      fake_series = Struct.new(:slug, :file_path) do
        define_method(:event_series_record) { :series_record }
        define_method(:merge_old_events!) { |record| calls << [:merge, slug, record] }
        define_method(:update_meetup_frequency!) { |record| calls << [:frequency, slug, record] }
      end
      fake_event = Struct.new(:slug, :file_path, :series, :old_talk_ids) do
        define_method(:migrate_old_talks!) { |record| calls << [:migrate, slug, record] }
      end

      series = fake_series.new("rug-b", Rails.root.join("data/rug-b/series.yml").to_s)
      event = fake_event.new("rug-b-2012-11-01", Rails.root.join("data/rug-b/rug-b-2012-11-01/event.yml").to_s, series, ["rug-b-old-talk"])
      record = Struct.new(:slug).new("rug-b-2012-11-01")

      Static::DataImporter.stub(:event_for, event) do
        Static::DataImporter.stub(:series_for, series) do
          ::Event.stub(:where, [record]) do
            failed = Static::DataImporter.finalize!(["data/rug-b/rug-b-2012-11-01/videos.yml", "data/rug-b/rug-b-2012-11-01/event.yml"], logger: ->(_) {})

            assert_empty failed
          end
        end
      end

      assert_equal [[:migrate, "rug-b-2012-11-01", record], [:merge, "rug-b", :series_record], [:frequency, "rug-b", :series_record]], calls
    end

    test "finalize! skips the database lookup for events without old_talk_ids" do
      fake_series = Struct.new(:slug, :file_path) do
        define_method(:event_series_record) { :series_record }
        define_method(:merge_old_events!) { |_record| }
        define_method(:update_meetup_frequency!) { |_record| }
      end
      fake_event = Struct.new(:slug, :file_path, :series, :old_talk_ids) do
        define_method(:migrate_old_talks!) { |_record| flunk "should not migrate" }
      end

      series = fake_series.new("rug-b", Rails.root.join("data/rug-b/series.yml").to_s)
      event = fake_event.new("rug-b-2012-11-01", Rails.root.join("data/rug-b/rug-b-2012-11-01/event.yml").to_s, series, [])
      queried_slugs = nil

      Static::DataImporter.stub(:event_for, event) do
        Static::DataImporter.stub(:series_for, series) do
          ::Event.stub(:where, ->(slug:) { (queried_slugs = slug) && [] }) do
            assert_empty Static::DataImporter.finalize!(["data/rug-b/rug-b-2012-11-01/videos.yml"], logger: ->(_) {})
          end
        end
      end

      assert_equal [], queried_slugs
    end

    test "finalize! reports a failing series and forgets its fingerprint so it is retried" do
      relative = "data/rug-b/series.yml"
      ImportedFile.create!(file_path: relative, fingerprint: "current")
      fake_series = Struct.new(:slug, :file_path) do
        define_method(:event_series_record) { raise "boom" }
      end
      series = fake_series.new("rug-b", Rails.root.join(relative).to_s)

      Static::DataImporter.stub(:series_for, series) do
        failed = Static::DataImporter.finalize!([relative], logger: ->(_) {})

        assert_equal [relative], failed
      end

      assert_not ImportedFile.exists?(file_path: relative)
    end

    test "remove returns false when the event is not in the database" do
      ::Event.stub(:find_by, nil) do
        assert_equal false, Static::DataImporter.remove("data/rubyconf/rubyconf-2024/sponsors.yml")
      end
    end
  end
end
