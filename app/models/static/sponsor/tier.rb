# frozen_string_literal: true

module Static
  class Sponsor
    class Tier < Yerba::Record::Base
      has_one :event, through: :parent
      has_one :series, through: :parent

      has_many :sponsors, nested: true, class_name: "Static::Sponsor::Entry"
    end
  end
end
