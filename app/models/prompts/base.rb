module Prompts
  class Base
    MODEL = "gpt-4.1-nano"

    def to_params
      {
        model: model,
        response_format: response_format,
        messages: messages
      }
    end

    private

    def model
      self.class::MODEL
    end

    def response_format
      {type: "json_object"}
    end

    def messages
      [
        {role: "system", content: system_message},
        {role: "user", content: prompt}
      ]
    end

    def system_message
      raise NotImplementedError, "Subclass #{self.class.name} must implement #system_message"
    end

    def prompt
      raise NotImplementedError, "Subclass #{self.class.name} must implement #prompt"
    end
  end
end
