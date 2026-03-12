class Avo::Dashboards::Duplicates < Avo::Dashboards::BaseDashboard
  self.id = "duplicates"
  self.name = "Duplicate Detection"
  self.description = "Find potential duplicate user profiles"
  self.grid_cols = 3

  def cards
    card Avo::Cards::SameNameDuplicatesMetric
    card Avo::Cards::ReversedNameDuplicatesMetric
    card Avo::Cards::SameNameDuplicatesList
    card Avo::Cards::ReversedNameDuplicatesList
  end
end
