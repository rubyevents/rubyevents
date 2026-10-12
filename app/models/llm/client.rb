class LLM::Client
  def chat(parameters:, resource:, task_name:)
    response = LLM::Request.find_or_create_by_request!(parameters, resource: resource, task_name: task_name) do
      {"content" => complete(parameters)}
    end

    response.dig("choices", 0, "message", "content") || response["content"]
  end

  def complete(parameters)
    model, messages = parameters.values_at(:model, :messages)
    params = parameters.except(:model, :messages).compact
    system_message = messages.find { |m| m[:role] == "system" }&.dig(:content)
    user_message = messages.find { |m| m[:role] == "user" }&.dig(:content)

    chat = RubyLLM.chat(model: model)
    chat.with_instructions(system_message) if system_message
    chat.with_provider_options(params) if params.any?
    chat.ask(user_message).content
  end
end
