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

      Static::EventSeries.stub(:find_by_slug, series) do
        assert Static::DataImporter.import("data/rubyconf/series.yml")
      end

      series.verify
    end

    test "routes event.yml and venue.yml to Event#import_event!" do
      %w[event venue].each do |basename|
        static_event = Minitest::Mock.new
        static_event.expect(:import_event!, true)

        Static::Event.stub(:find_by_slug, static_event) do
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
        static_event.expect(method, true, [record])

        Static::Event.stub(:find_by_slug, static_event) do
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
      static_event.expect(:import_event!, record)
      static_event.expect(:import_videos!, true, [record])

      Static::Event.stub(:find_by_slug, static_event) do
        ::Event.stub(:find_by, nil) do
          assert Static::DataImporter.import("data/rubyconf/rubyconf-2024/videos.yml")
        end
      end

      static_event.verify
    end

    test "returns false when the event is unknown in the data files" do
      Static::Event.stub(:find_by_slug, nil) do
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
  end
end
