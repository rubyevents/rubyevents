# frozen_string_literal: true

require "gum"

namespace :event_recordings_published_date do
  desc "Reconcile recordings_published_date across all event.yml files (meetups, majority rule, P90/date correction). Pass DRY_RUN=1 to preview."
  task fix: :environment do
    dry_run = ENV["DRY_RUN"].present?
    validator = Static::Validators::EventRecordingsPublishedDate

    parse_date = ->(value) do
      Date.parse(value.to_s)
    rescue Date::Error, TypeError
      nil
    end

    scalar = ->(node) { node.respond_to?(:value) ? node.value : node }

    top_level_items = ->(videos_path) do
      document = Yerba.parse_file(videos_path)
      document.root ? document.root.each.to_a : []
    end

    majority_published = ->(providers) do
      watchable = providers.count { |p| validator::WATCHABLE_PROVIDERS.include?(p) }
      resolvable = providers.count { |p| !validator::TERMINAL_PROVIDERS.include?(p) }
      resolvable.positive? && watchable * 2 > resolvable
    end

    changes = []

    Dir.glob(Rails.root.join("data/**/event.yml")).sort.each do |path|
      document = Yerba.parse_file(path)
      present = document["recordings_published_date"].present?
      videos_path = File.join(File.dirname(path), "videos.yml")
      relative = path.sub("#{Rails.root}/", "")

      if scalar.call(document["kind"]) == "meetup"
        changes << {path:, relative:, action: :delete, value: nil} if present

        next
      end

      next unless File.exist?(videos_path)

      items = top_level_items.call(videos_path)

      next if items.empty?

      providers = items.map { |item| item.value_at("video_provider") }

      if majority_published.call(providers)
        dates = items.filter_map { |item| parse_date.call(item.value_at("published_at")) }
        target = [validator.percentile(dates), parse_date.call(scalar.call(document["end_date"]))].compact.max

        next unless target

        current = parse_date.call(scalar.call(document["recordings_published_date"])) if present

        next if current && current >= target

        changes << {path:, relative:, action: present ? :set : :insert, value: target.iso8601}
      elsif present
        changes << {path:, relative:, action: :delete, value: nil}
      end
    end

    if changes.empty?
      puts Gum.style("✓ All event.yml recordings_published_date values are already consistent", foreground: "2")
      next
    end

    puts Gum.style("#{dry_run ? "Would reconcile" : "Reconciling"} recordings_published_date on #{changes.size} event(s)", border: "rounded", padding: "0 2", border_foreground: "5")
    puts

    changes.each do |change|
      label = "#{change[:action].to_s.ljust(6)} #{(change[:value] || "").ljust(12)} #{change[:relative]}"
      color = (change[:action] == :delete) ? "1" : "2"
      puts Gum.style("  #{"[dry-run] " if dry_run}#{label}", foreground: color)

      next if dry_run

      document = Yerba.parse_file(change[:path])

      case change[:action]
      when :set
        document["recordings_published_date"] = change[:value]
        document["recordings_published_date"].quote_style = "double"
      when :insert
        document.insert("recordings_published_date", change[:value], after: "description")
        document["recordings_published_date"].quote_style = "double"
      when :delete
        document.delete("recordings_published_date")
      end

      document.save!(apply: true)
    end

    puts
    puts Gum.style(dry_run ? "Dry run — re-run without DRY_RUN=1 to apply" : "Done", foreground: dry_run ? "3" : "2")
  end
end
