class NormalizeSpeakerWebsite < ActiveRecord::Migration[8.0]
  def change
    # Fix an edge case where twitter and website are in the same field
    speaker = Speaker.find_by(slug: "derrick-ko")
    speaker.update(website: "http://derrickko.com", twitter: "http://twitter.com/derrickko")

    Speaker.where.not(website: [nil, ""]).find_in_batches do |speakers|
      speakers.each do |speaker|
        speaker.normalize_attribute(:website)
        speaker.save
      end
    end
  end
end
