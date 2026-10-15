# -*- SkipSchemaAnnotations

class Event::VideosFile < Event::DataFile
  data_file :talks, file_name: "videos.yml"

  extension do
    def talks_in_running_order(child_talks: true)
      talks.in_order_of(:static_id, videos_file.ids(child_talks: child_talks))
    end
  end

  def ids(child_talks: true)
    return [] unless exist?

    (child_talks ? static_association : static_association.top_level).ids
  end
end
