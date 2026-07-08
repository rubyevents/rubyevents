# frozen_string_literal: true

namespace :import do
  desc "Browse and import event series, events and talks with a TUI"
  task events: :environment do
    abort "import:events needs a TTY (use scripts/import_event.rb or Static::EventSeries#import! instead)" unless $stdout.tty?

    require_relative "../import/tui"

    Import::TUI.run
  end
end
