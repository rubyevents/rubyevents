# frozen_string_literal: true

require "test_helper"

class Static::Validators::EventRenamesTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "flags a new event when an event of the series from main is gone" do
    with_series(%w[testrb-meetup]) do |paths|
      stub_baseline("testrb-brigade" => ["data/testrb/testrb-brigade"]) do
        errors = Static::Validators::EventRenames.new(file_path: paths["testrb-meetup"]).errors

        assert_equal 1, errors.size
        assert_includes errors.first.message, %(event "testrb-meetup" is new, while "testrb-brigade" from main is gone)
      end
    end
  end

  test "does not flag a renamed event that keeps its previous id in old_ids" do
    with_series(%w[testrb-meetup], old_ids: {"testrb-meetup" => ["testrb-brigade"]}) do |paths|
      stub_baseline("testrb-brigade" => ["data/testrb/testrb-brigade"]) do
        assert_empty Static::Validators::EventRenames.new(file_path: paths["testrb-meetup"]).errors
      end
    end
  end

  test "does not flag a new event when every event of the series from main is still there" do
    with_series(%w[testrb-2025 testrb-2026]) do |paths|
      stub_baseline("testrb-2025" => ["data/testrb/testrb-2025"]) do
        assert_empty Static::Validators::EventRenames.new(file_path: paths["testrb-2026"]).errors
      end
    end
  end

  test "ignores events of other series that are gone" do
    with_series(%w[testrb-meetup]) do |paths|
      stub_baseline("otherrb" => ["data/otherrb/otherrb"]) do
        assert_empty Static::Validators::EventRenames.new(file_path: paths["testrb-meetup"]).errors
      end
    end
  end

  test "does not flag anything without a baseline" do
    with_series(%w[testrb-meetup]) do |paths|
      Static::Validators::EventRenames.stub(:baseline_ref, nil) do
        assert_empty Static::Validators::EventRenames.new(file_path: paths["testrb-meetup"]).errors
      end
    end
  end

  test "fix adds the previous id to old_ids when the rename is unambiguous" do
    with_series(%w[testrb-meetup]) do |paths|
      stub_baseline("testrb-brigade" => ["data/testrb/testrb-brigade"]) do
        Static::Validators::EventRenames.new(file_path: paths["testrb-meetup"]).fix

        assert_equal ["testrb-brigade"], Static::Event.in_file(paths["testrb-meetup"]).first["old_ids"]
      end
    end
  end

  test "fix leaves old_ids alone when two new events could be the rename" do
    with_series(%w[testrb-meetup testrb-workshop]) do |paths|
      stub_baseline("testrb-brigade" => ["data/testrb/testrb-brigade"]) do
        assert_nil Static::Validators::EventRenames.new(file_path: paths["testrb-meetup"]).fix
        assert_nil Static::Event.in_file(paths["testrb-meetup"]).first["old_ids"]
      end
    end
  end

  private

  def stub_baseline(directories, &block)
    Static::Validators::EventRenames.stub(:baseline_ref, "abc123") do
      Static::Validators::EventRenames.stub(:baseline_event_directories, directories) do
        Static::Validators::EventRenames.stub(:baseline_file, nil) do
          Static::Validators::EventRenames.stub(:changed_paths, nil, &block)
        end
      end
    end
  end

  def with_series(event_ids, old_ids: {})
    with_static_data_dir do |dir|
      paths = event_ids.to_h do |id|
        path = File.join(dir, "data", "testrb", id, "event.yml")
        FileUtils.mkdir_p(File.dirname(path))

        attributes = {"id" => id, "title" => "Test.rb", "kind" => "meetup"}
        attributes["old_ids"] = old_ids[id] if old_ids[id]
        File.write(path, Yerba::Document.from(attributes).to_s)

        [id, path]
      end

      File.write(File.join(dir, "data", "testrb", "series.yml"), Yerba::Document.from({"id" => "testrb", "name" => "Test.rb", "kind" => "meetup"}).to_s)

      yield paths
    end
  end
end
