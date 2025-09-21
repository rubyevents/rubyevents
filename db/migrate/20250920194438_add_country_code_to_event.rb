class AddCountryCodeToEvent < ActiveRecord::Migration[8.1]
  def up
    Event.find_each.each do |event|
      event.update_column(:country_code, event.static_metadata&.country&.alpha2)
    end
  end
end
