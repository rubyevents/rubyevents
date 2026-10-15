require "test_helper"

class MCPServerTest < ActiveSupport::TestCase
  class EchoTool < RubyLLM::Tool
    description "Echoes the given message."
    parameter :message, description: "Message to echo"
    parameter :times, description: "How often to repeat it", type: "integer", required: false

    def execute(message:, times: 1)
      {echo: [message] * times}
    end
  end

  class FailingTool < RubyLLM::Tool
    description "Always fails."

    def execute
      raise "boom"
    end
  end

  class InProcessTransport
    def initialize(server)
      @server = server
    end

    def request(message, version:, timeout: nil, headers: {})
      JSON.parse(JSON.generate(@server.handle_request(JSON.parse(JSON.generate(message)))))
    end

    def notify(message, version:)
      @server.handle_request(JSON.parse(JSON.generate(message)))
    end

    def cancel(notification, version:)
    end

    def close
    end
  end

  def self.discovered_server
    @discovered_server ||= MCPServer.new(log: StringIO.new)
  end

  setup do
    @server = MCPServer.new(tools: {"echo" => EchoTool, "failing" => FailingTool})
    @client = mcp_client(@server)
  end

  teardown do
    @client.close
  end

  test "discovers every tool in app/tools and every generator tool" do
    tool_names = self.class.discovered_server.tools.keys
    app_tool_names = Dir[Rails.root.join("app/tools/**/*_tool.rb")].map { |file| File.basename(file, "_tool.rb") }

    assert_empty app_tool_names - tool_names
    assert_includes tool_names, "generate_event"
    assert_includes tool_names, "generate_talk"
  end

  test "lists every discovered tool with its input schema" do
    server = self.class.discovered_server
    tools = mcp_client(server).tools

    assert_equal server.tools.keys, tools.map(&:name)

    tools.each do |tool|
      assert tool.description.present?, "#{tool.name} is missing a description"
      assert_equal server.tools[tool.name].new.parameters_schema, tool.parameters_schema
    end

    event_lookup = tools.find { |tool| tool.name == "event_lookup" }
    assert_equal ["query"], event_lookup.parameters_schema["properties"].keys
  end

  test "lists declared parameters as JSON schema properties" do
    echo = @client.tools.find { |tool| tool.name == "echo" }

    assert_equal "Echoes the given message.", echo.description
    assert_equal(
      {
        "message" => {"type" => "string", "description" => "Message to echo"},
        "times" => {"type" => "integer", "description" => "How often to repeat it"}
      },
      echo.parameters_schema["properties"]
    )
    assert_equal ["message"], echo.parameters_schema["required"]
  end

  test "calls a tool with the given arguments" do
    result = @client.echo(message: "hi", times: 2)

    refute result.error?
    assert_equal({"echo" => ["hi", "hi"]}, JSON.parse(result.text))
  end

  test "reports invalid tool arguments as an error result" do
    result = @client.echo(times: 2)

    assert result.error?
    assert_equal({"error" => "Invalid tool arguments: missing keyword: message"}, JSON.parse(result.text))
  end

  test "reports tool failures as an error result" do
    result = @client.failing

    assert result.error?
    assert_equal({"error" => "boom"}, JSON.parse(result.text))
  end

  test "returns an error for unknown tools" do
    response = @server.handle_request({"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call", "params" => {"name" => "nope"}})

    assert_equal(-32602, response[:error][:code])
  end

  test "initialize returns the protocol version and server info" do
    response = @server.handle_request({"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => {}})

    assert_equal MCPServer::PROTOCOL_VERSION, response[:result][:protocolVersion]
    assert_equal "rubyevents-mcp", response[:result][:serverInfo][:name]
  end

  test "notifications/initialized does not respond" do
    assert_nil @server.handle_request({"jsonrpc" => "2.0", "method" => "notifications/initialized"})
  end

  test "ping returns an empty result" do
    assert_equal({jsonrpc: "2.0", id: 7, result: {}}, @server.handle_request({"jsonrpc" => "2.0", "id" => 7, "method" => "ping"}))
  end

  test "unknown methods return a method not found error" do
    response = @server.handle_request({"jsonrpc" => "2.0", "id" => 1, "method" => "resources/list"})

    assert_equal(-32601, response[:error][:code])
  end

  test "run answers each JSON-RPC line and reports parse errors" do
    input = StringIO.new(<<~JSONL)
      {"jsonrpc":"2.0","id":1,"method":"ping"}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      not json
    JSONL
    output = StringIO.new

    MCPServer.run(tools: {"echo" => EchoTool}, input: input, output: output, log: StringIO.new)

    responses = output.string.lines.map { |line| JSON.parse(line) }
    assert_equal 2, responses.size
    assert_equal({"jsonrpc" => "2.0", "id" => 1, "result" => {}}, responses.first)
    assert_equal(-32700, responses.last.dig("error", "code"))
  end

  private

  def mcp_client(server)
    RubyLLM.mcp(name: "rubyevents", transport: InProcessTransport.new(server))
  end
end
