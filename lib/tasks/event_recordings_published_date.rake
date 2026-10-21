# frozen_string_literal: true

require "gum"

namespace :event_recordings_published_date do
  desc "Reconcile recordings_published_date across all event.yml files (meetups, majority rule, P90/date correction). Pass DRY_RUN=1 to preview."
  task fix: :environment do
    dry_run = ENV["DRY_RUN"].present?
    validator = Static::RecordingsPublishedDateValidator

    parse_date = ->(value) do
      Date.parse(value.to_s)
    rescue Date::Error, TypeError
      nil
    end

    majority_published = ->(providers) do
      watchable = providers.count { |p| validator::WATCHABLE_PROVIDERS.include?(p) }
      resolvable = providers.count { |p| !validator::TERMINAL_PROVIDERS.include?(p) }
      resolvable.positive? && watchable * 2 > resolvable
    end

    changes = []

    Static::Event.all.sort_by(&:file_path).each do |event|
      present = event.key?("recordings_published_date")
      relative = event.project_file_path

      if event["kind"] == "meetup"
        changes << {event:, relative:, action: :delete, value: nil} if present

        next
      end

      talks = Static::Talk.in_file(File.join(File.dirname(event.file_path), "videos.yml")).top_level
      providers = talks.pluck(:video_provider)

      if majority_published.call(providers)
        dates = talks.filter_map { |talk| parse_date.call(talk.published_at) }
        target = [validator.percentile(dates), parse_date.call(event["end_date"])].compact.max

        next unless target

        current = parse_date.call(event["recordings_published_date"]) if present

        next if current && current >= target

        changes << {event:, relative:, action: present ? :set : :insert, value: target.iso8601}
      elsif present
        changes << {event:, relative:, action: :delete, value: nil}
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

      event = change[:event]

      if change[:action] == :delete
        event.delete("recordings_published_date")
      else
        event.set("recordings_published_date", change[:value], after: "description", quote_style: :double)
      end

      event.save!
    end

    puts
    puts Gum.style(dry_run ? "Dry run — re-run without DRY_RUN=1 to apply" : "Done", foreground: dry_run ? "3" : "2")
  end
end
