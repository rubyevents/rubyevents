class Topic::GemInfo < ActiveRecord::AssociatedObject
  def gems
    topic.topic_gems
  end

  def gem?
    gems.any?
  end

  def primary_gem
    gems.first
  end
end
