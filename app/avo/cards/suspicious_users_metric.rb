class Avo::Cards::SuspiciousUsersMetric < Avo::Cards::MetricCard
  self.id = "suspicious_users_metric"
  self.label = "Suspicious Users"
  self.description = "Number of users flagged as suspicious"
  self.cols = 1

  def query
    result User.suspicious.count
  end
end
