# frozen_string_literal: true

namespace :talk_ids do
  desc "Rename talk ids that don't match the id convention, keeping the current id as old_id"
  task fix: :environment do
    renamed = 0
    files = 0

    Dir.glob(Rails.root.join("data/**/videos.yml")).sort.each do |path|
      validator = Static::Validators::TalkId.new(file_path: path)
      next unless validator.applicable?
      next unless validator.errors.any?

      result = validator.fix
      renamed += result[:changed]
      files += 1
      puts "#{path.to_s.sub("#{Rails.root}/", "")}: renamed #{result[:changed]} id(s)"
    end

    puts
    puts "Renamed #{renamed} talk id(s) across #{files} file(s)"
  end

  desc "Write old_id for talks whose id changed since the branch's merge-base with main"
  task backfill_old_ids: :environment do
    written = 0

    Dir.glob(Rails.root.join("data/**/videos.yml")).sort.each do |path|
      validator = Static::Validators::TalkRenames.new(file_path: path)
      next unless validator.applicable?

      relative_path = path.to_s.sub("#{Rails.root}/", "")

      validator.disappeared_ids.each do |id|
        puts "⚠ #{relative_path}: id \"#{id}\" disappeared and can't be matched to a talk, restore it manually if the talk was renamed"
      end

      renames = validator.renamed_talks.select { |node, _previous_id| node.value_at("old_id").blank? }
      next if renames.empty?

      renames.each do |node, previous_id|
        node["old_id"] = previous_id
        puts "#{relative_path}: #{node.value_at("id")} was renamed, keeping old_id: \"#{previous_id}\""
      end

      validator.current.save!

      written += renames.size
    end

    puts
    puts "Wrote #{written} old_id(s)"
  end

  desc "Remove old_id keys once production has been re-seeded with the new ids"
  task remove_old_ids: :environment do
    removed = 0

    Static::VideosFile.all.each do |file|
      nodes = file.talks.select { |node| node.value_at("old_id").present? }
      next if nodes.empty?

      nodes.each { |node| node.delete("old_id") }
      file.save!

      removed += nodes.size
      puts "#{file.relative_path}: removed #{nodes.size} old_id(s)"
    end

    puts
    puts "Removed #{removed} old_id(s)"
  end
end
