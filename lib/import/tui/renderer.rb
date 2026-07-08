# frozen_string_literal: true

module Import
  module TUI
    module Renderer
      LOG_LINES = 6

      def view
        lines = []

        lines << render_header
        lines << render_filter_bar if @filter_mode || !@filter.empty?
        lines << ""
        lines << render_body
        lines.concat(render_log)
        lines << ""
        lines << render_help

        lines.join("\n")
      end

      private

      def render_header
        badge = @theme.title.render(" IMPORT ")
        imported_series = @tree.count { |node| node[:imported] }

        left = " #{badge} #{@theme.bold.render("rubyevents importer")}"
        right = @theme.muted.render("#{imported_series}/#{@tree.length} series imported")

        padding = [@width - visible_length(left) - visible_length(right) - 1, 1].max

        left + (" " * padding) + right
      end

      def render_filter_bar
        if @filter_mode
          "  #{@theme.filter.render("/")} #{@filter}#{@theme.filter.render("█")}"
        else
          "  #{@theme.filter.render("Filter:")} #{@filter} #{@theme.muted.render("(#{rows.length} rows, esc clears)")}"
        end
      end

      def render_body
        tree_width = [(@width * 0.58).to_i, 48].max
        preview_width = [@width - tree_width - 4, 24].max

        tree = render_tree(tree_width, body_height)
        preview = @theme.preview_border.render(render_preview(preview_width, body_height))

        Lipgloss.join_horizontal(:top, tree, " ", preview)
      end

      def render_tree(width, height)
        visible = rows[@scroll, height] || []

        lines = visible.map do |row|
          text = "#{"  " * row[:depth]}#{row_icon(row)} #{row[:label]}"
          text = truncate(text, width - 2)

          if rows[@cursor] == row
            @theme.cursor.render(pad(" #{strip_ansi(text)}", width))
          else
            pad(" #{text}", width)
          end
        end

        lines << pad(" #{@theme.muted.render("(no matches)")}", width) if visible.empty?
        lines.fill(pad("", width), lines.length...height)

        lines.join("\n")
      end

      def row_icon(row)
        node = row[:node]

        case row[:kind]
        when :series
          icon = node[:expanded] ? "▾" : "▸"
          status = series_status(node)
          "#{status} #{@theme.accent.render(icon)}"
        when :event
          icon = node[:expanded] ? "▾" : "▸"
          "#{event_status(node)} #{@theme.info.render(icon)}"
        when :talk
          "  #{@theme.pending.render("·")}"
        when :loading
          "  #{@spinner.view}"
        when :empty
          "   "
        end
      end

      def series_status(node)
        if node[:status] == :importing
          @spinner.view
        elsif node[:status] == :failed
          @theme.fail.render("✗")
        elsif node[:imported]
          @theme.pass.render("●")
        else
          @theme.pending.render("○")
        end
      end

      def event_status(node)
        if node[:status] == :importing
          @spinner.view
        elsif node[:status] == :failed
          @theme.fail.render("✗")
        elsif node[:imported]
          @theme.pass.render("✓")
        else
          @theme.pending.render("·")
        end
      end

      def render_preview(width, height)
        row = rows[@cursor]
        lines = row ? preview_lines(row, width - 2) : []

        lines = lines.map { |line| truncate(line, width - 2) }
        lines.fill("", lines.length...(height - 2))

        lines.map { |line| pad(line, width - 2) }.join("\n")
      end

      def preview_lines(row, width)
        node = row[:node]

        case row[:kind]
        when :series then series_preview(node)
        when :event, :empty then event_preview(node)
        when :talk then talk_preview(node)
        when :loading then [@theme.muted.render("Loading talks…")]
        else []
        end
      end

      def series_preview(node)
        events = node[:events] || build_event_nodes(node)
        imported = events.count { |event| event[:imported] }

        [
          @theme.bold.render(node[:name]),
          @theme.muted.render(node[:slug]),
          "",
          field("Kind", node[:series_kind]),
          field("Frequency", node[:frequency]),
          field("Language", node[:language]),
          field("Website", node[:website]),
          "",
          field("Events", "#{events.length} (#{imported} imported)"),
          field("Imported", node[:imported] ? "yes" : "no"),
          "",
          @theme.muted.render("i imports the series with all events")
        ].compact
      end

      def event_preview(node)
        talks = node[:talks]

        talks_line = if talks
          "#{talks.length} talks"
        elsif node[:loading]
          "loading…"
        else
          "press enter to load"
        end

        [
          @theme.bold.render(node[:name]),
          @theme.muted.render(node[:slug]),
          "",
          field("Kind", node[:event_kind]),
          field("Dates", format_dates(node)),
          field("Location", node[:location]),
          "",
          field("Talks", talks_line),
          field("Imported", node[:imported] ? "yes" : "no"),
          "",
          @theme.muted.render("i imports this event")
        ].compact
      end

      def talk_preview(node)
        [
          @theme.bold.render(node[:title].to_s),
          "",
          field("Speakers", Array(node[:speakers]).join(", ")),
          field("Kind", node[:talk_kind]),
          field("Date", node[:date]),
          field("Language", node[:language]),
          field("Provider", node[:provider]),
          field("Video", node[:video_id]),
          field("Slides", node[:slides_url])
        ].compact
      end

      def field(label, value)
        return nil if value.nil? || value.to_s.strip.empty?

        "#{@theme.muted.render(label.ljust(10))} #{value}"
      end

      def format_dates(node)
        return nil if node[:start_date].to_s.empty?
        return node[:start_date].to_s if node[:start_date] == node[:end_date] || node[:end_date].to_s.empty?

        "#{node[:start_date]} → #{node[:end_date]}"
      end

      def render_log
        lines = [""]
        lines << " #{@theme.muted.render("─" * [@width - 2, 0].max)}"

        visible = @log.last(LOG_LINES)
        visible = [""] * (LOG_LINES - visible.length) + visible

        visible.each do |line|
          lines << " #{@theme.muted.render(truncate(line, @width - 2))}"
        end

        lines
      end

      def render_help
        bindings = []
        bindings << ["↑↓", "navigate"]
        bindings << ["enter", "expand"]
        bindings << ["i", "import"] unless @importing
        bindings << ["/", "filter"]
        bindings << ["q", "quit"]

        help = bindings.map { |key, description| "#{@theme.help_key.render(key)} #{@theme.help.render(description)}" }
        " #{help.join(@theme.help.render(" • "))}"
      end

      def body_height
        reserved = 4 + LOG_LINES + 2
        reserved += 1 if @filter_mode || !@filter.empty?

        [@height - reserved, 8].max
      end

      def strip_ansi(string)
        ::Bubbles::ANSI.strip(string)
      end

      def visible_length(string)
        strip_ansi(string).length
      end

      def truncate(string, width)
        return string if visible_length(string) <= width

        "#{::Bubbles::ANSI.cut_string(string, 0, width - 1)}…"
      end

      def pad(string, width)
        padding = width - visible_length(string)
        padding.positive? ? string + (" " * padding) : string
      end
    end
  end
end
