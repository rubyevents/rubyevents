# -*- SkipSchemaAnnotations

class Event::SponsorsFile < Event::DataFile
  data_file :sponsors, file_name: "sponsors.yml"
end
