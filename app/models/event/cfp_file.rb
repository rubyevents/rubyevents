# -*- SkipSchemaAnnotations

class Event::CFPFile < Event::DataFile
  data_file :cfps, file_name: "cfp.yml"
end
