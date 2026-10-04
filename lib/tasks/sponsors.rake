# frozen_string_literal: true

namespace :sponsors do
  desc "Rename sponsor slugs that don't match the parameterized sponsor name"
  task fix_slugs: :environment do
    renamed = 0
    files = 0

    Dir.glob(Rails.root.join("data/**/sponsors.yml")).sort.each do |path|
      validator = Static::Validators::SponsorSlug.new(file_path: path)
      next unless validator.applicable?
      next unless validator.errors.any?

      result = validator.fix
      renamed += result[:changed]
      files += 1
      puts "#{path.to_s.sub("#{Rails.root}/", "")}: renamed #{result[:changed]} slug(s)"
    end

    puts
    puts "Renamed #{renamed} sponsor slug(s) across #{files} file(s)"
  end
end
