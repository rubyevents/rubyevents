require "test_helper"
require_relative "../../app/tools/cfp_create_tool"

class CFPCreateToolTest < ActiveSupport::TestCase
  setup do
    @event = events(:rails_world_2023)
    @tmp_dir = Dir.mktmpdir
    @data_folder = Pathname.new(@tmp_dir)
  end

  teardown do
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && File.exist?(@tmp_dir)
  end

  test "creates cfp.yml file when it does not exist" do
    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com",
      open_date: "2025-01-01",
      close_date: "2025-02-01"
    )

    assert result[:success]
    assert_equal @event.name, result[:event]
    assert File.exist?(File.join(@tmp_dir, "cfp.yml"))

    assert_equal <<~STRING, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Call for Proposals
        link: https://cfp.example.com
        open_date: '2025-01-01'
        close_date: '2025-02-01'
    STRING

    cfp_content = YAML.load_file(File.join(@tmp_dir, "cfp.yml"))
    assert_equal 1, cfp_content.size
    assert_equal "Call for Proposals", cfp_content.first["name"]
    assert_equal "https://cfp.example.com", cfp_content.first["link"]
    assert_equal "2025-01-01", cfp_content.first["open_date"]
    assert_equal "2025-02-01", cfp_content.first["close_date"]
  end

  test "adds to existing cfp.yml file" do
    existing_cfp = [{"name" => "Existing CFP", "link" => "https://existing-cfp.com", "open_date" => "2024-01-01"}]
    File.write(File.join(@tmp_dir, "cfp.yml"), existing_cfp.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://new-cfp.example.com",
      open_date: "2025-01-01"
    )

    assert result[:success]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Existing CFP
        link: https://existing-cfp.com
        open_date: '2024-01-01'
      - name: Call for Proposals
        link: https://new-cfp.example.com
        open_date: '2025-01-01'
    YAML
  end

  test "returns error when event is not found" do
    tool = CFPCreateTool.new

    result = tool.execute(
      event_query: "non-existent-event",
      link: "https://cfp.example.com"
    )

    assert result[:error]
    assert_match(/not found/i, result[:error])
  end

  test "returns error when CFP with same link already exists" do
    existing_cfp = [{"link" => "https://cfp.example.com", "open_date" => "2024-01-01"}]
    File.write(File.join(@tmp_dir, "cfp.yml"), existing_cfp.to_yaml)

    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com"
    )

    assert result[:error]
    assert_match(/already exists/i, result[:error])
  end

  test "does not include open_date when not provided" do
    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com"
    )

    assert result[:success]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Call for Proposals
        link: https://cfp.example.com
    YAML
  end

  test "includes optional name field when provided" do
    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.slug,
      link: "https://cfp.example.com",
      name: "Lightning Talks CFP"
    )

    assert result[:success]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Lightning Talks CFP
        link: https://cfp.example.com
    YAML
  end

  test "finds event by name" do
    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: @event.name,
      link: "https://cfp.example.com"
    )

    assert result[:success]
    assert_equal @event.name, result[:event]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Call for Proposals
        link: https://cfp.example.com
    YAML
  end

  test "finds event by partial search" do
    tool = build_tool_with_tmp_data_folder

    result = tool.execute(
      event_query: "Rails World",
      link: "https://cfp.example.com"
    )

    assert result[:success]
    assert_equal @event.name, result[:event]

    assert_equal <<~YAML, File.read(File.join(@tmp_dir, "cfp.yml"))
      ---
      - name: Call for Proposals
        link: https://cfp.example.com
    YAML
  end

  private

  def build_tool_with_tmp_data_folder
    data_folder = @data_folder
    event = @event

    tool = CFPCreateTool.new
    tool.define_singleton_method(:find_event) do |query|
      found = Event.find_by(slug: query) ||
        Event.find_by(slug: query.parameterize) ||
        Event.find_by(name: query) ||
        Event.ft_search(query).first

      return nil unless found
      return found unless found.id == event.id

      # Override data_folder for the matched event
      found.define_singleton_method(:data_folder) { data_folder }
      found
    end
    tool
  end
end
