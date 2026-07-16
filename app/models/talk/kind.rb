class Talk::Kind
  def self.from_title(title)
    case title.to_s
    when /^(keynote:|keynote|opening\ keynote:|opening\ keynote|closing\ keynote:|closing\ keynote).*/i
      :keynote
    when /^(lightning\ talk:|lightning\ talk|lightning\ talks|micro\ talk:|micro\ talk).*/i
      :lightning_talk
    when /^(open\ mic:|open\ mic|open\ mics|open\ mic\ night).*/i
      :open_mic
    when /^announcements?(:|\s|$).*/i
      :announcement
    when /^(city\ pitch:|city\ pitch|city\ pitches).*/i
      :city_pitch
    when /\bpanel\b/i
      :panel
    when /^(workshop:|workshop).*/i
      :workshop
    when /^(gameshow|game\ show|gameshow:|game\ show:).*/i
      :gameshow
    when /^(podcast:|podcast\ recording:|live\ podcast:).*/i
      :podcast
    when /.*(q&a|q&a:|q&a\ with|questions\ and\ answers).*/i,
        /.*(ruby\ committers\ vs\ the\ world|ruby\ committers\ and\ the\ world).*/i,
        /.*(AMA)$/,
        /^(AMA:)/
      :q_and_a
    when /^(fishbowl:|fishbowl\ discussion:|discussion:|discussion).*/i
      :discussion
    when /^(fireside\ chat:|fireside\ chat).*/i
      :fireside_chat
    when /^(award:|award\ show|ruby\ hero(es)?\ awards?|rails\ luminary).*/i
      :award
    when /^(interview:|interview\ with).*/i
      :interview
    when /^(demo:|demo\ |Startup\ Demo:).*/i, /.*(demo)$/i
      :demo
    when /.*(trailer).*/i
      :trailer
    when /\brecaps?\b/i
      :recap
    when /.*(after\ ?movie).*/i
      :aftermovie
    when /^intro(:|\s*$|\s+(?!to\b|of\b))/i, /^introduction(:|\s*$)/i, /^(opening\ (remarks|session|address|words)|welcome\b|day\ (opening|start)\b).*/i
      :intro
    when /^(outro:?|closing\ remarks:?|closing\ words|closing\ session|closing\ address|day\ (closing|end)).*/i
      :outro
    else
      :talk
    end
  end
end
