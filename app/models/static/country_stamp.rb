# frozen_string_literal: true

module Static
  class CountryStamp < Stamp
    self.path = "app/assets/images/stamps/:country_code.webp"
    self.constraints = {country_code: /[a-z]{2}/}

    def owner
      return @owner if defined?(@owner)

      @owner = ::Country.find_by(country_code: country_code.upcase)
    end
  end
end
