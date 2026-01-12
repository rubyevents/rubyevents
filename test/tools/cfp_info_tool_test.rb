require "test_helper"
require_relative "../../app/tools/cfp_info_tool"

class CFPInfoToolTest < ActiveSupport::TestCase
  setup do
    @event = events(:rails_world_2023)
    @tmp_dir = Dir.mktmpdir
    @data_folder = Pathname.new(@tmp_dir)
  end

  teardown do
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && File.exist?(@tmp_dir)
  end

  test "returns CFP information when CFP exists" do
    cfp_data = [
      {
        "name" => "Call for Proposals",
        "link" => "https://cfp.example.com",
        "open_date" => "2024-01-01",
        "close_date" => "2024-02-01"
      }
    ]
    File.write(File.join(@tmp_dir, "cfp.yml"), cfp_data.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.slug)

    assert_equal @event.name, result[:event]
    assert_equal 1, result[:cfps].size

    cfp = result[:cfps].first
    assert_equal "Call for Proposals", cfp[:name]
    assert_equal "https://cfp.example.com", cfp[:link]
    assert_equal "2024-01-01", cfp[:open_date]
    assert_equal "2024-02-01", cfp[:close_date]
  end

  test "returns empty array when no CFP file exists" do
    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.slug)

    assert_equal @event.name, result[:event]
    assert_equal [], result[:cfps]
    assert_equal "No CFPs found for this event", result[:message]
  end

  test "returns error when event is not found" do
    tool = CFPInfoTool.new

    result = tool.execute(event_query: "non-existent-event")

    assert result[:error]
    assert_match(/not found/i, result[:error])
  end

  test "returns multiple CFPs when event has multiple" do
    cfp_data = [
      {"name" => "Main CFP", "link" => "https://cfp.example.com"},
      {"name" => "Lightning Talks", "link" => "https://lightning.example.com"}
    ]
    File.write(File.join(@tmp_dir, "cfp.yml"), cfp_data.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.slug)

    assert_equal 2, result[:cfps].size
    assert_equal "Main CFP", result[:cfps][0][:name]
    assert_equal "Lightning Talks", result[:cfps][1][:name]
  end

  test "status is closed when close_date is in the past" do
    cfp_data = [
      {
        "name" => "CFP",
        "link" => "https://cfp.example.com",
        "open_date" => "2020-01-01",
        "close_date" => "2020-02-01"
      }
    ]
    File.write(File.join(@tmp_dir, "cfp.yml"), cfp_data.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.slug)

    assert_equal "closed", result[:cfps].first[:status]
  end

  test "status is upcoming when open_date is in the future" do
    cfp_data = [
      {
        "name" => "CFP",
        "link" => "https://cfp.example.com",
        "open_date" => "2099-01-01",
        "close_date" => "2099-02-01"
      }
    ]
    File.write(File.join(@tmp_dir, "cfp.yml"), cfp_data.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.slug)

    assert_equal "upcoming", result[:cfps].first[:status]
  end

  test "status is open when today is between open and close dates" do
    today = Date.current
    cfp_data = [
      {
        "name" => "CFP",
        "link" => "https://cfp.example.com",
        "open_date" => (today - 10.days).to_s,
        "close_date" => (today + 10.days).to_s
      }
    ]
    File.write(File.join(@tmp_dir, "cfp.yml"), cfp_data.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.slug)

    assert_equal "open", result[:cfps].first[:status]
  end

  test "status is open when only open_date is set and it is in the past" do
    cfp_data = [
      {
        "name" => "CFP",
        "link" => "https://cfp.example.com",
        "open_date" => "2020-01-01"
      }
    ]
    File.write(File.join(@tmp_dir, "cfp.yml"), cfp_data.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.slug)

    assert_equal "open", result[:cfps].first[:status]
  end

  test "status is unknown when no dates are set" do
    cfp_data = [
      {
        "name" => "CFP",
        "link" => "https://cfp.example.com"
      }
    ]
    File.write(File.join(@tmp_dir, "cfp.yml"), cfp_data.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.slug)

    assert_equal "unknown", result[:cfps].first[:status]
  end

  test "finds event by name" do
    cfp_data = [{"link" => "https://cfp.example.com"}]
    File.write(File.join(@tmp_dir, "cfp.yml"), cfp_data.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(event_query: @event.name)

    assert_equal @event.name, result[:event]
  end

  private

  def build_tool_with_tmp_data_folder
    data_folder = @data_folder
    event = @event

    tool = CFPInfoTool.new
    tool.define_singleton_method(:find_event) do |query|
      found = Event.find_by(slug: query) ||
        Event.find_by(slug: query.parameterize) ||
        Event.find_by(name: query) ||
        Event.ft_search(query).first

      return nil unless found
      return found unless found.id == event.id

      found.define_singleton_method(:data_folder) { data_folder }
      found
    end

    tool
  end
end
