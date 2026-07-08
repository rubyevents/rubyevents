# frozen_string_literal: true

module Import
  module TUI
    module KeyHandler
      def handle_key(message)
        return handle_filter_key(message) if @filter_mode

        case message.to_s
        when "q", "ctrl+c"
          [self, ::Bubbletea.quit]
        when "j", "down"
          move_cursor(1)
          [self, nil]
        when "k", "up"
          move_cursor(-1)
          [self, nil]
        when "g"
          @cursor = 0
          clamp_scroll
          [self, nil]
        when "G"
          @cursor = rows.length - 1
          clamp_scroll
          [self, nil]
        when "enter", "l", "right", "space"
          toggle_row(rows[@cursor])
          [self, nil]
        when "h", "left"
          collapse_row(rows[@cursor])
          [self, nil]
        when "i"
          request_import(rows[@cursor])
          [self, nil]
        when "/"
          @filter_mode = true
          [self, nil]
        else
          [self, nil]
        end
      end

      def handle_filter_key(message)
        case message.to_s
        when "enter"
          @filter_mode = false
        when "esc", "ctrl+c"
          @filter_mode = false
          @filter = ""
          reset_cursor
        when "backspace"
          @filter = @filter[0...-1].to_s
          reset_cursor
        when "space"
          @filter += " "
          reset_cursor
        else
          key = message.to_s

          if key.length == 1 && key.match?(/[[:print:]]/)
            @filter += key
            reset_cursor
          end
        end

        [self, nil]
      end

      private

      def move_cursor(delta)
        @cursor = (@cursor + delta).clamp(0, [rows.length - 1, 0].max)
        clamp_scroll
      end

      def reset_cursor
        @cursor = 0
        @scroll = 0
        @rows = nil
      end

      def toggle_row(row)
        return unless row

        node = row[:node]

        case row[:kind]
        when :series
          node[:expanded] = !node[:expanded]
          load_events(node) if node[:expanded] && node[:events].nil?
        when :event
          node[:expanded] = !node[:expanded]
          load_talks(node) if node[:expanded] && node[:talks].nil? && !node[:loading]
        end

        @rows = nil
        clamp_scroll
      end

      def collapse_row(row)
        return unless row

        node = row[:node]

        if [:series, :event].include?(row[:kind]) && node[:expanded]
          node[:expanded] = false
        elsif row[:parent]
          index = rows.index { |candidate| candidate[:node].equal?(row[:parent]) }

          @cursor = index if index
        end

        @rows = nil
        clamp_scroll
      end

      def request_import(row)
        return unless row
        return if @importing
        return unless [:series, :event].include?(row[:kind])

        node = row[:node]
        @importing = {kind: row[:kind], slug: node[:slug]}
        node[:status] = :importing

        @log << "→ importing #{row[:kind]} #{node[:slug]}"

        @commands.puts(JSON.generate(kind: row[:kind].to_s, slug: node[:slug]))
        @commands.flush
      end
    end
  end
end
