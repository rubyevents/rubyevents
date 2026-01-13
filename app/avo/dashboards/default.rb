class Avo::Dashboards::Default < Avo::Dashboards::BaseDashboard
  self.id = "default"
  self.name = "Dashboard"
  self.description = "Overview of key metrics and alerts"
  self.grid_cols = 3

  def cards
    card Avo::Cards::DuplicatesSummary
    card Avo::Cards::SuspiciousSummary
    card Avo::Cards::UnavailableVideosSummary
  end
end
