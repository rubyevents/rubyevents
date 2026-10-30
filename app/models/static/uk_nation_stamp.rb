# frozen_string_literal: true

module Static
  class UKNationStamp < Stamp
    self.path = "app/assets/images/stamps/gb-:nation_code.webp"

    def owner
      return @owner if defined?(@owner)

      @owner = ::UKNation.find_by_code(nation_code)
    end
  end
end
