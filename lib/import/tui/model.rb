# frozen_string_literal: true

require "bubbletea"
require "lipgloss"
require "bubbles"

require_relative "theme"
require_relative "key_handler"
require_relative "renderer"

module Import
  module TUI
    class Model
      include ::Bubbletea::Model
      include KeyHandler
      include Renderer

      def initialize(series:, imported_series:, imported_events:, queue:, commands:)
        @imported_events = imported_events
        @queue = queue
        @commands = commands
        @theme = Theme.new

        @tree = series.map do |entry|
          {
            kind: :series,
            slug: entry.slug,
            name: (entry.try(:name) || entry.slug).to_s,
            series_kind: entry.try(:kind),
            frequency: entry.try(:frequency),
            language: entry.try(:language),
            website: entry.try(:website),
            imported: imported_series.include?(entry.slug),
            expanded: false,
            status: nil,
            ref: entry,
            events: nil
          }
        end

        @cursor = 0
        @scroll = 0
        @rows = nil
        @filter = ""
        @filter_mode = false
        @importing = nil
        @log = []
        @width = 120
        @height = 36

        @spinner = ::Bubbles::Spinner.new(spinner: ::Bubbles::Spinners::DOT)
        @spinner.style = @theme.accent
      end

      def importing? = !@importing.nil?

      def init
        [self, @spinner.tick]
      end

      def update(message)
        case message
        when ::Bubbletea::WindowSizeMessage
          @width = message.width
          @height = message.height

          [self, nil]
        when ::Bubbles::Spinner::TickMessage
          drain_queue

          @spinner, command = @spinner.update(message)

          [self, command]
        when ::Bubbletea::KeyMessage
          handle_key(message)
        else
          [self, nil]
        end
      end

      private

      def rows
        @rows ||= filtered_tree.flat_map { |node| series_rows(node) }
      end

      def filtered_tree
        return @tree if @filter.empty?

        needle = @filter.downcase

        @tree.select { |node| node[:name].downcase.include?(needle) || node[:slug].downcase.include?(needle) }
      end

      def series_rows(node)
        count = node[:events]&.length || node[:ref].events.length
        label = "#{node[:name]} #{@theme.muted.render("(#{count} #{(count == 1) ? "event" : "events"})")}"
        result = [{kind: :series, node: node, depth: 0, label: label, parent: nil}]

        return result unless node[:expanded]

        node[:events] ||= build_event_nodes(node)

        node[:events].each do |event_node|
          result.concat(event_rows(event_node, node))
        end

        result
      end

      def event_rows(node, series_node)
        label = "#{node[:name]} #{@theme.muted.render(node[:start_date].to_s)}"
        result = [{kind: :event, node: node, depth: 1, label: label, parent: series_node}]

        return result unless node[:expanded]

        if node[:talks]
          result << {kind: :empty, node: node, depth: 2, label: @theme.muted.render("(no talks)"), parent: node} if node[:talks].empty?

          node[:talks].each do |talk_node|
            speakers = Array(talk_node[:speakers]).join(", ")
            label = talk_node[:title].to_s
            label = "#{label} #{@theme.muted.render("— #{speakers}")}" unless speakers.empty?

            result << {kind: :talk, node: talk_node, depth: 2 + talk_node[:extra_depth], label: label, parent: node}
          end
        elsif node[:loading]
          result << {kind: :loading, node: node, depth: 2, label: @theme.muted.render("loading talks…"), parent: node}
        end

        result
      end

      def build_event_nodes(series_node)
        series_node[:events] = series_node[:ref].events.map do |event|
          {
            kind: :event,
            slug: event.slug,
            name: (event.try(:title) || event.slug).to_s,
            event_kind: event.try(:kind),
            start_date: event.try(:start_date),
            end_date: event.try(:end_date),
            location: event.try(:location),
            imported: @imported_events.include?(event.slug),
            expanded: false,
            status: nil,
            loading: false,
            talks: nil
          }
        end
      end

      def load_events(node)
        build_event_nodes(node)
      end

      def load_talks(node)
        node[:loading] = true

        @commands.puts(JSON.generate(kind: "talks", slug: node[:slug]))
        @commands.flush
      end

      def adopt_talks(event)
        each_event_node do |event_node|
          next unless event_node[:slug] == event[:slug]

          event_node[:talks] = event[:talks].map { |talk| talk.transform_keys(&:to_sym).merge(kind: :talk) }
          event_node[:loading] = false
        end

        @log << "✗ loading talks for #{event[:slug]} failed: #{event[:error]}" if event[:error]

        @rows = nil
      end

      def each_event_node(&block)
        @tree.each do |series_node|
          series_node[:events]&.each(&block)
        end
      end

      def drain_queue
        while (event = begin
          @queue.pop(true)
        rescue ThreadError
          nil
        end)
          handle_worker_event(event)
        end
      end

      def handle_worker_event(event)
        case event[:type]
        when "log"
          @log << ::Bubbles::ANSI.strip(event[:line].to_s).delete("\r")

          @log.shift while @log.length > 200
        when "talks"
          adopt_talks(event)
        when "import_done"
          finish_import(event, failed: false)
        when "import_failed"
          @log << "✗ #{event[:kind]} #{event[:slug]} failed: #{event[:error]}"

          finish_import(event, failed: true)
        end
      end

      def finish_import(event, failed:)
        @importing = nil
        node = find_import_node(event[:kind], event[:slug])

        return unless node

        node[:status] = failed ? :failed : nil

        unless failed
          @log << "✓ imported #{event[:kind]} #{event[:slug]}"

          node[:imported] = true

          node[:events]&.each { |event_node| event_node[:imported] = true } if event[:kind] == "series"
        end

        @rows = nil
      end

      def find_import_node(kind, slug)
        if kind == "series"
          @tree.find { |node| node[:slug] == slug }
        else
          result = nil

          each_event_node { |node| result = node if node[:slug] == slug }

          result
        end
      end

      def clamp_scroll
        height = body_height

        @cursor = @cursor.clamp(0, [rows.length - 1, 0].max)
        @scroll = @cursor if @cursor < @scroll
        @scroll = @cursor - height + 1 if @cursor >= @scroll + height
        @scroll = @scroll.clamp(0, [rows.length - height, 0].max)
      end
    end
  end
end
