# frozen_string_literal: true

require "test_helper"

class Static::EventRenamesValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "flags a new event when an event of the series from main is gone" do
    with_series(%w[testrb-meetup]) do |events|
      stub_baseline("testrb-brigade" => ["data/testrb/testrb-brigade"]) do
        event = events["testrb-meetup"]
        errors = rename_errors(event)

        assert_equal 1, errors.size
        assert_includes errors.first.message, %(event "testrb-meetup" is new, while "testrb-brigade" from main is gone)
        assert_equal 2, event.error_location(errors.first).start_line
      end
    end
  end

  test "does not flag a renamed event that keeps its previous id in old_ids" do
    with_series(%w[testrb-meetup], old_ids: {"testrb-meetup" => ["testrb-brigade"]}) do |events|
      stub_baseline("testrb-brigade" => ["data/testrb/testrb-brigade"]) do
        assert_empty rename_errors(events["testrb-meetup"])
      end
    end
  end

  test "does not flag a new event when every event of the series from main is still there" do
    with_series(%w[testrb-2025 testrb-2026]) do |events|
      stub_baseline("testrb-2025" => ["data/testrb/testrb-2025"]) do
        assert_empty rename_errors(events["testrb-2026"])
      end
    end
  end

  test "ignores events of other series that are gone" do
    with_series(%w[testrb-meetup]) do |events|
      stub_baseline("otherrb" => ["data/otherrb/otherrb"]) do
        assert_empty rename_errors(events["testrb-meetup"])
      end
    end
  end

  test "does not flag anything without a baseline" do
    with_series(%w[testrb-meetup]) do |events|
      Static::EventRenamesValidator.stub(:baseline_ref, nil) do
        assert_empty rename_errors(events["testrb-meetup"])
      end
    end
  end

  test "fix adds the previous id to old_ids when the rename is unambiguous" do
    with_series(%w[testrb-meetup]) do |events, paths|
      stub_baseline("testrb-brigade" => ["data/testrb/testrb-brigade"]) do
        Yerba::Record.fix_all([events["testrb-meetup"]], only: Static::EventRenamesValidator)

        assert_equal ["testrb-brigade"], Static::Event.in_file(paths["testrb-meetup"]).first["old_ids"]
      end
    end
  end

  test "fix leaves old_ids alone when two new events could be the rename" do
    with_series(%w[testrb-meetup testrb-workshop]) do |events, paths|
      stub_baseline("testrb-brigade" => ["data/testrb/testrb-brigade"]) do
        assert_empty Yerba::Record.fix_all([events["testrb-meetup"]], only: Static::EventRenamesValidator)
        assert_nil Static::Event.in_file(paths["testrb-meetup"]).first["old_ids"]
      end
    end
  end

  private

  def rename_errors(event)
    event.valid?(:lint)
    event.errors.select { |error| error.message.include?("from main is gone") }
  end

  def stub_baseline(directories, &block)
    Static::EventRenamesValidator.stub(:baseline_ref, "abc123") do
      Static::EventRenamesValidator.stub(:baseline_event_directories, directories) do
        Static::EventRenamesValidator.stub(:baseline_file, nil) do
          Static::EventRenamesValidator.stub(:changed_paths, nil, &block)
        end
      end
    end
  end

  def with_series(event_ids, old_ids: {})
    with_static_data_dir do |root|
      paths = event_ids.to_h do |id|
        path = File.join(root, "data", "testrb", id, "event.yml")
        FileUtils.mkdir_p(File.dirname(path))

        attributes = {"id" => id, "title" => "Test.rb", "kind" => "meetup"}
        attributes["old_ids"] = old_ids[id] if old_ids[id]
        File.write(path, Yerba::Document.from(attributes).to_s)

        [id, path]
      end

      File.write(File.join(root, "data", "testrb", "series.yml"), Yerba::Document.from({"id" => "testrb", "name" => "Test.rb", "kind" => "meetup"}).to_s)

      yield paths.transform_values { |path| Static::Event.in_file(path).first }, paths
    end
  end
end
