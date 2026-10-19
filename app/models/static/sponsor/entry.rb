# frozen_string_literal: true

module Static
  class Sponsor
    class Entry < Yerba::Record::Base
      has_one :event, through: :parent
      has_one :series, through: :parent
    end
  end
end
