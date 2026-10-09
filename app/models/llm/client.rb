class LLM::Client
  def chat(parameters:, resource:, task_name:)
    response = LLM::Request.find_or_create_by_request!(parameters, resource: resource, task_name: task_name) do
      model = parameters[:model]
      messages = parameters[:messages]
      system_message = messages.find { |m| m[:role] == "system" }&.dig(:content)
      user_message = messages.find { |m| m[:role] == "user" }&.dig(:content)

      chat = RubyLLM.chat(model: model)
      chat.with_instructions(system_message) if system_message
      chat.ask(user_message)

      {"content" => chat.messages.last.content}
    end

    # Handle both new format and legacy OpenAI format from cached responses
    response.dig("choices", 0, "message", "content") || response["content"]
  end
end
