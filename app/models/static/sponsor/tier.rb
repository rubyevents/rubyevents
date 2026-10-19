# frozen_string_literal: true

module Static
  class Sponsor
    class Tier < Yerba::Record::Base
      has_many :sponsors, nested: true, class_name: "Static::Sponsor::Entry"
    end
  end
end
