class NormalizeSpeakerWebsite < ActiveRecord::Migration[8.0]
  def change
    Speaker.where.not(website: [nil, ""]).find_in_batches do |speakers|
      speakers.each do |speaker|
        speaker.normalize_attribute(:website)
        speaker.save
      end
    end
  end
end
