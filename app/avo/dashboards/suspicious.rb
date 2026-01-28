class Avo::Dashboards::Suspicious < Avo::Dashboards::BaseDashboard
  self.id = "suspicious"
  self.name = "Suspicious Users"
  self.description = "Monitor and manage suspicious user accounts"
  self.grid_cols = 3

  def cards
    card Avo::Cards::SuspiciousUsersMetric
    card Avo::Cards::SuspiciousSignalsBreakdown
    card Avo::Cards::SuspiciousUsersList
  end
end
