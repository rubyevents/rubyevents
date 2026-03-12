class Avo::Cards::SameNameDuplicatesMetric < Avo::Cards::MetricCard
  self.id = "same_name_duplicates_metric"
  self.label = "Same Name Duplicates"
  self.description = "Users with identical names"
  self.cols = 1

  def query
    result User::DuplicateDetector.same_name_duplicate_ids.count
  end
end
