require "rails/generators"

module Generators
  class EventBase < Rails::Generators::Base
    class_option :event_series, type: :string, desc: "Event series folder name - defaults to the series of the event", required: false, group: "Fields"
    class_option :event, type: :string, desc: "Event folder name", required: true, aliases: ["-e"], group: "Fields"

    # For files that also exist for a whole series, like a meetup group's organizers in data/lrug/involvements.yml
    def self.series_level_files!
      class_option :event, type: :string, desc: "Event folder name. Not needed with --series-level", required: false, aliases: ["-e"], group: "Fields"
      class_option :series_level, type: :boolean, default: false, desc: "Write the series' file instead of an event's, like a meetup group's data/lrug/involvements.yml", group: "Options"
    end

    # Helpers, not generator steps
    no_commands do
      def event_directory
        @event_directory ||= File.join(series_directory, event_folder)
      end

      # The series folder, nested ones included: "data/rails-girls/rails-girls-bern".
      def series_directory
        @series_directory ||= File.join(destination_root, "data", static_series&.directory || event_series_slug)
      end

      def event_folder
        static_event&.[]("id") || options[:event]
      end

      def event_series_slug
        @series_slug ||= options[:event_series]
          || static_event&.series_slug
          || say_error("Could not determine event series.", :red)
      end

      def static_series
        return @static_series if defined?(@static_series)

        @static_series = Static::EventSeries.find_by_slug(event_series_slug.to_s)
      end

      def static_event
        return @static_event if defined?(@static_event)

        @static_event = Static::Event.find_by_slug(options[:event].to_s)
      end
    end

    private

    # The event's folder, or the series' with --series-level
    def target_directory
      raise Thor::RequiredArgumentMissingError, "No value provided for required options '--event'" if !options[:series_level] && options[:event].blank?

      options[:series_level] ? series_directory : event_directory
    end

    def destination_path(path)
      File.join(destination_root, path)
    end

    def geocode_address(name:, address:)
      if address.present? || name.present?
        # Combine venue name and address for better accuracy with Google
        search = [name, address].compact.join(", ")
        geocode_results = Geocoder.search(search)
        # Nominatim works better with separate queries - doesn't find the combined one
        geocode_results = Geocoder.search(address) if geocode_results.empty?
        geocode_results = Geocoder.search(name) if geocode_results.empty?
        # Nominatim works better with just the street address
        geocode_results = Geocoder.search(address.split(",")[0]) if address.present? && geocode_results.empty?
        geocode_results&.first
      end
    end

    def template_content(source, &block)
      source = File.expand_path(find_in_source_paths(source.to_s))
      context = instance_eval("binding", __FILE__, __LINE__)
      capturable_erb = CapturableERB.new(::File.binread(source), trim_mode: "-", eoutvar: "@output_buffer")
      content = capturable_erb.tap do |erb|
        erb.filename = source
      end.result(context)
      content = yield(content) if block
      content
    end
  end
end

class CapturableERB < ERB
  def set_eoutvar(compiler, eoutvar = "_erbout")
    compiler.put_cmd = "#{eoutvar}.concat"
    compiler.insert_cmd = "#{eoutvar}.concat"
    compiler.pre_cmd = ["#{eoutvar} = ''.dup"]
    compiler.post_cmd = [eoutvar]
  end
end
