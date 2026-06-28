# frozen_string_literal: true

class Talk
  module Kind
    module_function

    def from(title:, static_kind:)
      return static_kind if static_kind.present?

      from_title(title)
    end

    def from_title(title)
      case title
      when /^(keynote:|keynote|opening\ keynote:|opening\ keynote|closing\ keynote:|closing\ keynote).*/i
        "keynote"
      when /^(lightning\ talk:|lightning\ talk|lightning\ talks|micro\ talk:|micro\ talk).*/i
        "lightning_talk"
      when /.*(panel:|panel).*/i
        "panel"
      when /^(workshop:|workshop).*/i
        "workshop"
      when /^(gameshow|game\ show|gameshow:|game\ show:).*/i
        "gameshow"
      when /^(podcast:|podcast\ recording:|live\ podcast:).*/i
        "podcast"
      when /.*(q&a|q&a:|q&a\ with|questions\ and\ answers).*/i,
          /.*(ruby\ committers\ vs\ the\ world|ruby\ committers\ and\ the\ world).*/i,
          /.*(AMA)$/,
          /^(AMA:)/
        "q_and_a"
      when /^(fishbowl:|fishbowl\ discussion:|discussion:|discussion).*/i
        "discussion"
      when /^(fireside\ chat:|fireside\ chat).*/i
        "fireside_chat"
      when /^(award:|award\ show|ruby\ heroes\ awards|ruby\ heroes\ award|rails\ luminary).*/i
        "award"
      when /^(interview:|interview\ with).*/i
        "interview"
      when /^(demo:|demo\ |Startup\ Demo:).*/i, /.*(demo)$/i
        "demo"
      else
        "talk"
      end
    end
  end
end
