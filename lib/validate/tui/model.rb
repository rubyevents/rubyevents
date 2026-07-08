# frozen_string_literal: true

require "bubbletea"
require "lipgloss"
require "bubbles"

module Validate
  module TUI
    class Model
      include ::Bubbletea::Model

      def initialize(titles, queue)
        @queue = queue
        @sections = titles.to_h { |title| [title, {status: :pending, started_at: nil, elapsed: nil}] }
        @done = false
        @passed = nil
        @aborted = false
        @started_at = monotonic_now

        @spinner = ::Bubbles::Spinner.new(spinner: ::Bubbles::Spinners::DOT)
        @spinner.style = Lipgloss::Style.new.foreground("205")

        @title_style = Lipgloss::Style.new.bold(true)
        @run_badge_style = Lipgloss::Style.new.foreground("255").background("99").bold(true)
        @pass_badge_style = Lipgloss::Style.new.foreground("255").background("2").bold(true)
        @fail_badge_style = Lipgloss::Style.new.foreground("255").background("196").bold(true)
        @pending_style = Lipgloss::Style.new.foreground("243")
        @pass_style = Lipgloss::Style.new.foreground("2").bold(true)
        @fail_style = Lipgloss::Style.new.foreground("196").bold(true)
        @muted_style = Lipgloss::Style.new.foreground("241")
      end

      def aborted? = @aborted

      def failures
        @sections
          .select { |_title, section| section[:status] == :failed }
          .to_h { |title, section| [title, section[:output]] }
      end

      def init
        [self, @spinner.tick]
      end

      def update(message)
        case message
        when ::Bubbles::Spinner::TickMessage
          drain_queue

          @spinner, command = @spinner.update(message)

          @done ? [self, ::Bubbletea.quit] : [self, command]
        when ::Bubbletea::KeyMessage
          case message.to_s
          when "q", "ctrl+c"
            @aborted = true unless @done
            [self, ::Bubbletea.quit]
          else
            [self, nil]
          end
        else
          [self, nil]
        end
      end

      def view
        width = @sections.keys.map(&:length).max

        lines = [""]
        lines << " #{badge} #{@title_style.render("rails validate:all")} #{@muted_style.render(format_elapsed(monotonic_now - @started_at))}"
        lines << ""

        @sections.each do |title, section|
          icon = case section[:status]
          when :pending then @pending_style.render("○")
          when :running then @spinner.view
          when :passed then @pass_style.render("✓")
          when :failed then @fail_style.render("✗")
          end

          style = (section[:status] == :pending) ? @pending_style : Lipgloss::Style.new
          elapsed = section_elapsed(section)

          lines << "  #{icon} #{style.render(title.ljust(width))} #{@muted_style.render(elapsed)}"
        end

        lines << ""
        finished = @sections.values.count { |section| [:passed, :failed].include?(section[:status]) }
        lines << "  #{@muted_style.render("#{finished}/#{@sections.size} sections")}#{@muted_style.render(" • q abort") unless @done}"

        failures.each do |title, output|
          next if output.nil? || output.empty?

          lines << ""
          lines << "  #{@fail_style.render("✗ #{title}")}"
          lines << ""

          output.each_line { |line| lines << "      #{line.chomp}" }
        end

        lines << ""

        lines.join("\n")
      end

      private

      def badge
        if @done
          @passed ? @pass_badge_style.render(" PASS ") : @fail_badge_style.render(" FAIL ")
        else
          @run_badge_style.render(" RUN ")
        end
      end

      def drain_queue
        while (event = begin
          @queue.pop(true)
        rescue ThreadError
          nil
        end)
          case event[:type]
          when "section_start"
            @sections[event[:title]][:status] = :running
            @sections[event[:title]][:started_at] = monotonic_now
          when "section_result"
            @sections[event[:title]][:status] = event[:passed] ? :passed : :failed
            @sections[event[:title]][:output] = event[:output]
            @sections[event[:title]][:elapsed] = monotonic_now - (@sections[event[:title]][:started_at] || monotonic_now)
          when "done"
            @done = true
            @passed = event[:passed]
          end
        end
      end

      def section_elapsed(section)
        if section[:elapsed]
          format_elapsed(section[:elapsed])
        elsif section[:started_at]
          format_elapsed(monotonic_now - section[:started_at])
        else
          ""
        end
      end

      def format_elapsed(seconds)
        (seconds < 60) ? format("%.1fs", seconds) : format("%dm%02ds", seconds / 60, seconds % 60)
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
