# -*- SkipSchemaAnnotations

class Event::CFPFile < ActiveRecord::AssociatedObject
  FILE_NAME = "cfp.yml"

  def file_path
    event.data_folder.join(FILE_NAME)
  end

  def exist?
    file_path.exist?
  end

  def entries
    return [] unless exist?

    YAML.load_file(file_path) || []
  end

  def find_by_link(link)
    entries.find { |cfp| cfp["link"] == link }
  end

  def add(link:, open_date: nil, close_date: nil, name: nil)
    return {error: "A CFP with this link already exists"} if find_by_link(link)

    new_entry = build_entry(link: link, open_date: open_date, close_date: close_date, name: name)
    write(entries + [new_entry])

    new_entry
  end

  def update(link:, open_date: nil, close_date: nil, name: nil)
    existing = find_by_link(link)
    return {error: "No CFP found with this link"} unless existing

    updated_entries = entries.map do |cfp|
      next cfp unless cfp["link"] == link

      cfp["name"] = name if name.present?
      cfp["open_date"] = open_date if open_date.present?
      cfp["close_date"] = close_date if close_date.present?
      cfp
    end

    write(updated_entries)

    find_by_link(link)
  end

  def write(cfps)
    File.write(file_path, cfps.to_yaml)
  end

  private

  def build_entry(link:, open_date:, close_date:, name:)
    entry = {}
    entry["name"] = name if name.present?
    entry["link"] = link
    entry["open_date"] = open_date if open_date.present?
    entry["close_date"] = close_date if close_date.present?
    entry
  end
end
