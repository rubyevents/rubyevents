# frozen_string_literal: true

# Records find their event, series, talks and schedule through the loaded Static models,
# like `talk.event`. Include this in tests that write event folders, and write them into
# the `data/` directory of the yielded root, so the models find them instead of data/.
module StaticDataSandbox
  def self.models
    [
      Static::EventSeries,
      Static::Event,
      Static::Talk,
      Static::Schedule,
      Static::Venue,
      Static::Involvement,
      Static::CFP,
      Static::Sponsor
    ]
  end

  def with_static_data_dir
    root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(root, "data"))

    previous = StaticDataSandbox.models.to_h { |model| [model, model.instance_variable_get(:@root)] }
    previous.each_key do |model|
      model.root = root
      model.unload!
    end

    yield root
  ensure
    previous&.each do |model, previous_root|
      model.root = previous_root
      model.unload!
    end

    FileUtils.rm_rf(root) if root
  end
end
