class Avo::Filters::Provider < Avo::Filters::SelectFilter
  self.name = "Provider"

  def apply(request, query, provider)
    if provider
      query.where("provider is ?", provider)
    else
      query
    end
  end

  def options
    ConnectedAccount.providers
  end
end
