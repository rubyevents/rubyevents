require "rails/generators"

module Generators
  class EventBase < Rails::Generators::Base
    class_option :event_series, type: :string, desc: "Event series folder name", required: true, group: "Fields"
    class_option :event, type: :string, desc: "Event folder name", required: true, aliases: ["-e"], group: "Fields"
  end
end
