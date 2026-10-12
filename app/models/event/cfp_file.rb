# -*- SkipSchemaAnnotations

class Event::CFPFile < Event::DataFile
  data_file :cfps, file_name: "cfp.yml"

  def find_by_link(link)
    entries.find { |cfp| cfp["link"] == link }
  end
end
