class ApplicationClient
  class Error < StandardError; end

  class Forbidden < Error; end

  class Unauthorized < Error; end

  class RateLimit < Error; end

  class NotFound < Error; end

  class InternalError < Error; end

  BASE_URI = "https://example.org"
  NET_HTTP_ERRORS = [Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError]

  def initialize(token: nil)
    @token = token
  end

  def default_headers
    {
      "Accept" => content_type,
      "Content-Type" => content_type
    }.merge(authorization_header)
  end

  def content_type
    "application/json"
  end

  def authorization_header
    token ? {"Authorization" => "Bearer #{token}"} : {}
  end

  def default_query_params
    {}
  end

  def get(path, headers: {}, query: nil)
    make_request(klass: Net::HTTP::Get, path: path, headers: headers, query: query)
  end

  def post(path, headers: {}, query: nil, body: nil, form_data: nil)
    make_request(
      klass: Net::HTTP::Post,
      path: path,
      headers: headers,
      query: query,
      body: body,
      form_data: form_data
    )
  end

  def patch(path, headers: {}, query: nil, body: nil, form_data: nil)
    make_request(
      klass: Net::HTTP::Patch,
      path: path,
      headers: headers,
      query: query,
      body: body,
      form_data: form_data
    )
  end

  def put(path, headers: {}, query: nil, body: nil, form_data: nil)
    make_request(
      klass: Net::HTTP::Put,
      path: path,
      headers: headers,
      query: query,
      body: body,
      form_data: form_data
    )
  end

  def delete(path, headers: {}, query: nil, body: nil)
    make_request(klass: Net::HTTP::Delete, path: path, headers: headers, query: query, body: body)
  end

  def base_uri
    self.class::BASE_URI
  end

  attr_reader :token

  def make_request(klass:, path:, headers: {}, body: nil, query: nil, form_data: nil)
    raise ArgumentError, "Cannot pass both body and form_data" if body.present? && form_data.present?

    uri = URI("#{base_uri}#{path}")
    existing_params = Rack::Utils.parse_query(uri.query).with_defaults(default_query_params)
    query_params = existing_params.merge(query || {})
    uri.query = Rack::Utils.build_query(query_params) if query_params.present?

    Rails.logger.debug("#{klass.name.split("::").last.upcase}: #{uri}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.instance_of? URI::HTTPS

    all_headers = default_headers.merge(headers)
    all_headers.delete("Content-Type") if klass == Net::HTTP::Get

    request = klass.new(uri.request_uri, all_headers)

    if body.present?
      request.body = build_body(body)
    elsif form_data.present?
      request.set_form(form_data, "multipart/form-data")
    end

    handle_response Response.new(http.request(request))
  end

  def handle_response(response)
    case response.code
    when "200", "201", "202", "203", "204"
      response
    when "401"
      raise Unauthorized, response.body
    when "403"
      raise Forbidden, response.body
    when "404"
      raise NotFound, response.body
    when "429"
      raise RateLimit, response.body
    when "500"
      raise InternalError, response.body
    else
      raise Error, "#{response.code} - #{response.body}"
    end
  end

  def build_body(body)
    case body
    when String
      body
    else
      body.to_json
    end
  end

  class Response
    JSON_OBJECT_CLASS = OpenStruct
    PARSER = {
      "application/json" => ->(response) { JSON.parse(response.body, object_class: JSON_OBJECT_CLASS) },
      "application/xml" => ->(response) { Nokogiri::XML(response.body) },
      "text/xml" => ->(response) { Nokogiri::XML(response.body) }
    }
    FALLBACK_PARSER = ->(response) { response.body }

    attr_reader :original_response

    delegate :code, :body, to: :original_response
    delegate_missing_to :parsed_body

    def initialize(original_response)
      @original_response = original_response
    end

    def headers
      @headers ||= original_response.each_header.to_h.transform_keys { |k| k.underscore.to_sym }
    end

    def content_type
      headers[:content_type].split(";").first
    end

    def parsed_body
      @parsed_body ||= PARSER.fetch(content_type, FALLBACK_PARSER).call(self)
    end
  end
end
