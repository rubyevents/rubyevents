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

  def self.discovered_server
    @discovered_server ||= MCPServer.new
  end

  setup do
    @server = MCPServer.new(tools: {"echo" => EchoTool, "failing" => FailingTool})
  end

  test "discovers every tool in app/tools and every generator tool" do
    tool_names = self.class.discovered_server.tools.keys
    app_tool_names = Dir[Rails.root.join("app/tools/**/*_tool.rb")].map { |file| File.basename(file, "_tool.rb") }

    assert_empty app_tool_names - tool_names
    assert_includes tool_names, "generate_event"
    assert_includes tool_names, "generate_talk"
  end

  test "tools/list builds a valid input schema for every discovered tool" do
    response = self.class.discovered_server.handle_request({"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"})

    assert_nil response[:error]

    tools = response[:result][:tools]
    assert_equal self.class.discovered_server.tools.size, tools.size

    tools.each do |tool|
      assert tool[:description].present?, "#{tool[:name]} is missing a description"

      schema = tool[:inputSchema]
      assert_equal "object", schema[:type]
      assert_empty schema[:required] - schema[:properties].keys, "#{tool[:name]} requires undeclared properties"
    end

    event_lookup = tools.find { |tool| tool[:name] == "event_lookup" }
    assert_equal ["query"], event_lookup[:inputSchema][:properties].keys
  end

  test "tools/list maps declared parameters to JSON schema properties" do
    response = @server.handle_request({"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"})
    echo = response[:result][:tools].find { |tool| tool[:name] == "echo" }

    assert_equal "Echoes the given message.", echo[:description]
    assert_equal(
      {
        type: "object",
        properties: {
          "message" => {type: "string", description: "Message to echo"},
          "times" => {type: "integer", description: "How often to repeat it"}
        },
        required: ["message"]
      },
      echo[:inputSchema]
    )
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

  test "tools/call executes the tool with the given arguments" do
    response = @server.handle_request({
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/call",
      "params" => {"name" => "echo", "arguments" => {"message" => "hi", "times" => 2}}
    })

    content = response[:result][:content].sole
    assert_equal "text", content[:type]
    assert_equal({"echo" => ["hi", "hi"]}, JSON.parse(content[:text]))
    assert_nil response[:result][:isError]
  end

  test "tools/call returns an error for unknown tools" do
    response = @server.handle_request({"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call", "params" => {"name" => "nope"}})

    assert_equal(-32602, response[:error][:code])
  end

  test "tools/call reports tool failures as error results" do
    response = @server.handle_request({"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call", "params" => {"name" => "failing"}})

    assert response[:result][:isError]
    assert_equal({"error" => "boom"}, JSON.parse(response[:result][:content].sole[:text]))
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
end
