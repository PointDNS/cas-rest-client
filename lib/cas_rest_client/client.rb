class CasRestClient::Client

  DEFAULT_OPTIONS = {:use_cookies => true}

  attr_accessor :tgt

  def initialize(only_tgt = nil, cas_opts = {})
    @cas_opts = DEFAULT_OPTIONS.merge(get_cas_config).merge(cas_opts)
    @tgt = "#{@cas_opts[:uri]}/#{only_tgt}" if only_tgt
  end

  def connect
    begin
      get_tgt
    rescue RestClient::BadRequest
      raise RestClient::Request::Unauthorized.new
    end
  end

  def get(uri, options = {})
    execute("get", uri, {}, options)
  end

  def delete(uri, params = {}, options = {})
    execute("delete", uri, params, options)
  end

  def post(uri, params = {}, options = {})
    execute("post", uri, params, options)
  end

  def put(uri, params = {}, options = {})
    execute("put", uri, params, options)
  end

  def destroy
    RestClient.delete(@tgt)
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

  def execute(method, uri, params, options)
    if @cas_opts[:use_cookies] and !@cookies.nil? and !@cookies.empty?
      begin
        execute_with_cookie(method, uri, params, options)
      rescue RestClient::Request::Unauthorized
        execute_with_tgt(method, uri, params, options)
      end
    else
      execute_with_tgt(method, uri, params, options)
    end
  end

  def execute_with_cookie(method, uri, params, options)
    args = [method, uri]
    args << params unless params.empty?
    args << {:cookies => @cookies}.merge(options)
    response = RestClient.send(*args)
    CasRestClient::Response.new response
  end

  def execute_with_tgt(method, uri, params, options)
    ticket = get_service_ticket(uri)

    response = execute_request(method, uri, ticket, params, options)

    @cookies = response.cookies
    CasRestClient::Response.new response, ticket
  end

  def execute_request(method, uri, ticket, params, options)
    original_uri = uri
    if @cas_opts[:ticket_header]
      options[@cas_opts[:ticket_header]] = ticket
    else
      uri = "#{uri}#{uri.include?("?") ? "&" : "?"}ticket=#{ticket}"
    end

    options = (@cas_opts[:headers] || {}).merge options
    begin
      if method == "get"
        RestClient.send(method, uri, options)
      else
        RestClient.send(method, uri, params || {}, options)
      end
    rescue RestClient::Found => e
      if method == 'post' && ( @cookies = e.response.cookies )
        execute_with_cookie method, original_uri, params, options
      else
        raise
      end
    end
  end

  def create_ticket(uri, params)
    ticket = RestClient.post(uri, params, @cas_opts[:headers] || {})
    ticket = ticket.body if ticket.respond_to? 'body'
    ticket
  end

  def get_tgt
    opts = @cas_opts.dup
    opts.delete(:service)
    opts.delete(:use_cookies)
    headers = opts.delete(:headers) || {}
    @tgt = RestClient.post(opts.delete(:uri), opts, headers).headers[:location]
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


