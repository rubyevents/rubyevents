# frozen_string_literal: true

module Import
  module TUI
    class Theme
      def title = @title ||= Lipgloss::Style.new.foreground("255").background("99").bold(true)
      def pass_badge = @pass_badge ||= Lipgloss::Style.new.foreground("255").background("2").bold(true)
      def fail_badge = @fail_badge ||= Lipgloss::Style.new.foreground("255").background("196").bold(true)
      def bold = @bold ||= Lipgloss::Style.new.bold(true)
      def muted = @muted ||= Lipgloss::Style.new.foreground("241")
      def pending = @pending ||= Lipgloss::Style.new.foreground("243")
      def pass = @pass ||= Lipgloss::Style.new.foreground("2").bold(true)
      def fail = @fail ||= Lipgloss::Style.new.foreground("196").bold(true)
      def accent = @accent ||= Lipgloss::Style.new.foreground("205")
      def info = @info ||= Lipgloss::Style.new.foreground("75")
      def cursor = @cursor ||= Lipgloss::Style.new.foreground("255").background("237").bold(true)
      def filter = @filter ||= Lipgloss::Style.new.foreground("220")
      def preview_border = @preview_border ||= Lipgloss::Style.new.border(:rounded).border_foreground("241")
      def help_key = @help_key ||= Lipgloss::Style.new.foreground("250")
      def help = @help ||= Lipgloss::Style.new.foreground("241")
    end
  end
end
