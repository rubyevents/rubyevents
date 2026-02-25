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

    # fix one by one - with nil checks for safety
    andrew_speaker = Speaker.find_by(name: "Andrew")
    andrew_nesbitt_speaker = Speaker.find_by(name: "Andrew Nesbitt")
    andrew_speaker&.assign_canonical_speaker!(canonical_speaker: andrew_nesbitt_speaker) if andrew_nesbitt_speaker

    hasumi_speaker = Speaker.find_by(name: "HASUMI Hitoshi")
    hitoshi_speaker = Speaker.find_by(name: "Hitoshi Hasumi")
    hasumi_speaker&.assign_canonical_speaker!(canonical_speaker: hitoshi_speaker) if hitoshi_speaker

    hogelog_speaker = Speaker.find_by(name: "hogelog")
    sunao_speaker = Speaker.find_by(name: "Sunao Hogelog Komuro")
    hogelog_speaker&.assign_canonical_speaker!(canonical_speaker: sunao_speaker) if sunao_speaker

    jonatas_speaker = Speaker.find_by(name: "Jônatas Paganini")
    jonatas_davi_speaker = Speaker.find_by(name: "Jônatas Davi Paganini")
    jonatas_speaker&.assign_canonical_speaker!(canonical_speaker: jonatas_davi_speaker) if jonatas_davi_speaker

    sutou_speaker = Speaker.find_by(name: "Sutou Kouhei")
    kouhei_speaker = Speaker.find_by(name: "Kouhei Sutou")
    sutou_speaker&.assign_canonical_speaker!(canonical_speaker: kouhei_speaker) if kouhei_speaker

    maciek_speaker = Speaker.find_by(slug: "maciek-rzasa")
    maciej_speaker = Speaker.find_by(slug: "maciej-rzasa")
    maciek_speaker&.assign_canonical_speaker!(canonical_speaker: maciej_speaker) if maciej_speaker

    mario_alberto_speaker = Speaker.find_by(slug: "mario-alberto-chavez")
    mario_speaker = Speaker.find_by(slug: "mario-chavez")
    mario_alberto_speaker&.assign_canonical_speaker!(canonical_speaker: mario_speaker) if mario_speaker

    enrique_morellon_speaker = Speaker.find_by(slug: "enrique-morellon")
    enrique_mogollan_speaker = Speaker.find_by(slug: "enrique-mogollan")
    enrique_morellon_speaker&.assign_canonical_speaker!(canonical_speaker: enrique_mogollan_speaker) if enrique_mogollan_speaker

    masafumi_speaker = Speaker.find_by(slug: "masafumi-okura")
    okura_speaker = Speaker.find_by(slug: "okura-masafumi")
    masafumi_speaker&.assign_canonical_speaker!(canonical_speaker: okura_speaker) if okura_speaker

    oliver_speaker = Speaker.find_by(slug: "oliver-lacan")
    olivier_speaker = Speaker.find_by(slug: "olivier-lacan")
    oliver_speaker&.assign_canonical_speaker!(canonical_speaker: olivier_speaker) if olivier_speaker
    add_index :speakers, :github, unique: true, where: "github IS NOT NULL AND github != ''"
  end

  def down
    remove_index :speakers, :github
  end
end
