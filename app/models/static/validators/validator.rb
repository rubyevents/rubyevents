module Static
  module Validators
    ALL = [
      Static::Validators::Schema,
      Static::Validators::SchemaArray,
      Static::Validators::EventDates,
      Static::Validators::UniqueSpeakerFields,
      Static::Validators::SpeakerExists,
      Static::Validators::ColorsHaveAssets
    ]

    class Base
    end
  end
end
