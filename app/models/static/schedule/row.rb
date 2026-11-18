# frozen_string_literal: true

module Static
  class Schedule
    class Row < Yerba::Record::Base
      def day
        parent
      end
    end
  end
end
