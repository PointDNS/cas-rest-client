class CasRestClient::Response

  attr_accessor :response, :ticket

  def initialize(response, ticket = nil)
    @response = response
    @ticket = ticket
  end

end


