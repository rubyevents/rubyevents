class AddUniqueIndexOnGitHubInSpeaker < ActiveRecord::Migration[8.0]
  def up
    # remove duplicate with no talks
    Speaker.group(:github).having("count(*) > 1").pluck(:github).each do |github|
      Speaker.where(github: github, talks_count: 0).update_all(github: "")
    end

    # some speaker with a canonical speaker still have talks attached to them let's reasign them
    Speaker.not_canonical.where.not(talks_count: 0).each do |speaker|
      speaker.assign_canonical_speaker!(canonical_speaker: speaker.canonical)
    end

    # fix one by one
    Speaker.find_by(name: "Andrew").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(name: "Andrew Nesbitt"))
    Speaker.find_by(name: "HASUMI Hitoshi").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(name: "Hitoshi Hasumi"))
    Speaker.find_by(name: "hogelog").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(name: "Sunao Hogelog Komuro"))
    Speaker.find_by(name: "Jônatas Paganini").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(name: "Jônatas Davi Paganini"))
    Speaker.find_by(name: "Sutou Kouhei").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(name: "Kouhei Sutou"))
    Speaker.find_by(slug: "maciek-rzasa").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(slug: "maciej-rzasa"))
    Speaker.find_by(slug: "mario-alberto-chavez").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(slug: "mario-chavez"))
    Speaker.find_by(slug: "enrique-morellon").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(slug: "enrique-mogollan"))
    Speaker.find_by(slug: "masafumi-okura").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(slug: "okura-masafumi"))
    Speaker.find_by(slug: "oliver-lacan").assign_canonical_speaker!(canonical_speaker: Speaker.find_by(slug: "olivier-lacan"))
    add_index :speakers, :github, unique: true, where: "github IS NOT NULL AND github != ''"
  end

  def down
    remove_index :speakers, :github
  end
end
