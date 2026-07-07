# frozen_string_literal: true

namespace :talk_ids do
  desc "Rename talk ids that don't match the id convention, keeping the current id as old_id"
  task fix: :environment do
    renamed = 0
    files = 0

    Dir.glob(Rails.root.join("data/**/videos.yml")).sort.each do |path|
      validator = Static::Validators::TalkId.new(file_path: path)
      next unless validator.applicable?

      renames = validator.expected_ids.reject { |node, expected| node.value_at("id") == expected }

      renames.each do |node, expected|
        current = node.value_at("id")
        placeholder_video_id = node.value_at("video_id") == current &&
          !node.value_at("video_provider").in?(%w[youtube vimeo mp4])

        node["old_id"] = current if node.value_at("old_id").blank?
        node["id"] = expected
        node["video_id"] = expected if placeholder_video_id
      end

      redundant = validator.expected_ids.keys.select { |node| node.value_at("old_id") == node.value_at("id") }
      redundant.each { |node| node.delete("old_id") }

      next if renames.empty? && redundant.empty?

      validator.document.save!(apply: true)

      renamed += renames.size
      files += 1
      puts "#{path.to_s.sub("#{Rails.root}/", "")}: renamed #{renames.size} id(s)"
    end

    puts
    puts "Renamed #{renamed} talk id(s) across #{files} file(s)"
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
