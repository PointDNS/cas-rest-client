class CasRestClient::Client

  attr_accessor :tgt

  def initialize(only_tgt = nil, request_opts = {}, cas_opts = {})
    @cas_opts = get_cas_config.merge(cas_opts)
    @request_opts = request_opts || {}
    @tgt = "#{@cas_opts[:uri]}/#{only_tgt}" if only_tgt
  end

  def connect
    begin
      get_tgt
    rescue RestClient::BadRequest
      raise RestClient::Unauthorized.new
    end
  end

  def post(uri, params = {})
    execute_with_tgt("post", uri, params)
  end

  def get_service_ticket(uri = nil)
    get_tgt unless @tgt

    begin
      ticket = create_ticket(@tgt, :service => @cas_opts[:service] || uri)
    rescue RestClient::ResourceNotFound
      get_tgt
      ticket = create_ticket(@tgt, :service => @cas_opts[:service] || uri)
    end
    ticket
  end

  private

  def execute_with_tgt(method, uri, params)
    ticket = get_service_ticket(uri)

    response = execute_request(method, uri, ticket, params)

    @cookies = response.cookies

    CasRestClient::Response.new response, ticket
  end

  def execute_request(method, uri, ticket, params)
    options = {}.merge(@request_opts)
    if @cas_opts[:ticket_header]
      options[:headers] ||= {}
      options[:headers][@cas_opts[:ticket_header]] = ticket
    else
      uri = "#{uri}#{uri.include?("?") ? "&" : "?"}ticket=#{ticket}"
    end
    if method == "get"
      RestClient::Request.execute({method: method, url: uri}.merge(options))
    else
      RestClient::Request.execute({method: method, url: uri, payload: params || {}}.merge(options))
    end
  end

  def create_ticket(uri, params)
    ticket = RestClient::Request.execute({
      method: 'post',
      url: uri,
      payload: params
    }.merge(@request_opts))
    ticket = ticket.body if ticket.respond_to? 'body'
    ticket
  end

  def get_tgt
    response = RestClient::Request.execute({
      method: 'post',
      url: @cas_opts[:uri],
      payload: @cas_opts[:payload]
    }.merge(@request_opts))
    @tgt = response.headers[:location]
  end

  def get_cas_config
    begin
      cas_config = YAML.load_file("config/cas_rest_client.yml")
      cas_config = cas_config[Rails.env] if defined?(Rails) and Rails.env

      cas_config = cas_config.inject({}) do |options, (key, value)|
        options[(key.to_sym rescue key) || key] = value
        options
      end
    rescue Exception
      cas_config = {}
    end
    cas_config
  end
end


