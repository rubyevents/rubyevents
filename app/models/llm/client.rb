class LLM::Client
  def initialize(provider_client = OpenAI::Client.new)
    @provider_client = provider_client
  end

  def chat(parameters:, resource:, task_name:)
    LLM::Request.find_or_create_by_request!(parameters, resource: resource, task_name: task_name) do
      @provider_client.chat(parameters: parameters)
    end
  end
end
