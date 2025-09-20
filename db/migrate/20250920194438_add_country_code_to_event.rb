class AddCountryCodeToEvent < ActiveRecord::Migration[8.1]
  def up
    Event.all.each do |event|
      event.update_column(:country_code, event.country&.alpha2)
    end
  end
end
