# frozen_string_literal: true

module Static
  class Talk
    class AlternativeRecording < Yerba::Record::Base
      has_one :event, through: :parent
      has_one :series, through: :parent

      references :speakers, class_name: "Static::Speaker"
    end
  end
end
