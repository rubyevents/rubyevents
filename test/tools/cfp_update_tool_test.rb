require "test_helper"
require_relative "../../app/tools/cfp_update_tool"

class CFPUpdateToolTest < ActiveSupport::TestCase
  setup do
    @event = events(:rails_world_2023)
    @tmp_dir = Dir.mktmpdir
    @data_folder = Pathname.new(@tmp_dir)
  end

  teardown do
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && File.exist?(@tmp_dir)
  end

  test "updates close_date on existing CFP" do
    existing_cfp = [{"name" => "Call for Proposal", "link" => "https://cfp.example.com", "open_date" => "2025-01-01"}]
    File.write(File.join(@tmp_dir, "cfp.yml"), existing_cfp.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com",
      close_date: "2025-02-15"
    )

    assert result[:success]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Call for Proposal
        link: https://cfp.example.com
        open_date: '2025-01-01'
        close_date: '2025-02-15'
    YAML
  end

  test "updates open_date on existing CFP" do
    existing_cfp = [{"name" => "Call for Proposal", "link" => "https://cfp.example.com"}]
    File.write(File.join(@tmp_dir, "cfp.yml"), existing_cfp.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com",
      open_date: "2025-01-15"
    )

    assert result[:success]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Call for Proposal
        link: https://cfp.example.com
        open_date: '2025-01-15'
    YAML
  end

  test "updates name on existing CFP" do
    existing_cfp = [{"name" => "Old Name", "link" => "https://cfp.example.com"}]
    File.write(File.join(@tmp_dir, "cfp.yml"), existing_cfp.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com",
      name: "New Name"
    )

    assert result[:success]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: New Name
        link: https://cfp.example.com
    YAML
  end

  test "updates multiple fields at once" do
    existing_cfp = [{"name" => "Call for Proposal", "link" => "https://cfp.example.com"}]
    File.write(File.join(@tmp_dir, "cfp.yml"), existing_cfp.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com",
      open_date: "2025-01-01",
      close_date: "2025-02-28"
    )

    assert result[:success]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Call for Proposal
        link: https://cfp.example.com
        open_date: '2025-01-01'
        close_date: '2025-02-28'
    YAML
  end

  test "returns error when CFP does not exist" do
    existing_cfp = [{"name" => "Call for Proposal", "link" => "https://other-cfp.com"}]
    File.write(File.join(@tmp_dir, "cfp.yml"), existing_cfp.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com",
      close_date: "2025-02-15"
    )

    assert result[:error]
    assert_match(/no cfp found/i, result[:error])
  end

  test "returns error when event is not found" do
    tool = CFPUpdateTool.new

    result = tool.execute(
      event_query: "non-existent-event",
      link: "https://cfp.example.com",
      close_date: "2025-02-15"
    )

    assert result[:error]
    assert_match(/not found/i, result[:error])
  end

  test "only updates the matching CFP when multiple exist" do
    existing_cfps = [
      {"name" => "Main CFP", "link" => "https://main-cfp.com", "open_date" => "2025-01-01"},
      {"name" => "Lightning Talks", "link" => "https://lightning-cfp.com", "open_date" => "2025-03-01"}
    ]
    File.write(File.join(@tmp_dir, "cfp.yml"), existing_cfps.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://lightning-cfp.com",
      close_date: "2025-04-15"
    )

    assert result[:success]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Main CFP
        link: https://main-cfp.com
        open_date: '2025-01-01'
      - name: Lightning Talks
        link: https://lightning-cfp.com
        open_date: '2025-03-01'
        close_date: '2025-04-15'
    YAML
  end

  private

  def build_tool_with_tmp_data_folder
    data_folder = @data_folder
    event = @event

    tool = CFPUpdateTool.new
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
