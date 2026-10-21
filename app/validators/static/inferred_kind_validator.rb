# frozen_string_literal: true

module Static
  class InferredKindValidator < ActiveModel::EachValidator
    DEFAULT_KIND = "talk"

    def validate_each(talk, attribute, _value)
      kind = talk[attribute].to_s.strip
      inferred = ::Talk::Kind.from_title(talk["title"]).to_s

      if kind.empty? && inferred != DEFAULT_KIND
        talk.errors.add(attribute, :not_inferred, **options, message: %(is inferred as "#{inferred}" from the title but is not set explicitly. Add `kind: "#{inferred}"` to the entry if this is a "#{inferred}". Otherwise you can explicitly set `kind: "talk"` if the title classifiier didn't get it right.))
      elsif kind == DEFAULT_KIND && inferred == DEFAULT_KIND && !Static::ShortTalkKindValidator.short?(talk)
        talk.errors.add(attribute, :redundant, **options, message: %("#{DEFAULT_KIND}" is redundant because the title already classifies as "#{DEFAULT_KIND}". Remove it (only keep an explicit "#{DEFAULT_KIND}" to override a non-default classification).))
      end
    end
  end
end
