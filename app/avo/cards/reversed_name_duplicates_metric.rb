class Avo::Cards::ReversedNameDuplicatesMetric < Avo::Cards::MetricCard
  self.id = "reversed_name_duplicates_metric"
  self.label = "Reversed Name Duplicates"
  self.description = "Number of users with potential duplicate profiles (name parts reversed)"
  self.cols = 1

  def query
    result User.with_reversed_name_duplicate.count
  end
end
