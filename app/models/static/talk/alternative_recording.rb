# frozen_string_literal: true

module Static
  class Talk
    class AlternativeRecording < Yerba::Record::Base
      references :speakers, class_name: "Static::Speaker"
    end
  end
end
