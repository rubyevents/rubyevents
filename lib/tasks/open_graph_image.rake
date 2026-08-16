namespace :og_image do
  desc "Generate the Open Graph image"
  task generate: :environment do
    output_path = OpenGraphImage.new.generate!
    puts "Generated #{output_path.relative_path_from(Rails.root)}"
  end
end
