# -*- SkipSchemaAnnotations

class Event::CFPFile < ActiveRecord::AssociatedObject
  include YAMLFile

  yaml_file "cfp.yml"

  def find_by_link(link)
    entries.find { |cfp| cfp["link"] == link }
  end
end
