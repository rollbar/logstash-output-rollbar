# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "json"
    
# The Rollbar output will send events to the Rollbar event monitoring service.
# The only required field is a Rollbar project access token with post_server_item
# permissions. If you're already using Rollbar to report errors directly from your
# applications, you can use the same token.
class LogStash::Outputs::Rollbar < LogStash::Outputs::Base
  config_name "rollbar"

  # Your Rollbar access token
  config :access_token, :validate => :password, :required => true

  # The Rollbar environment
  config :environment, :validate => :string, :default => 'production'

  # The default level for Rollbar events (info, warning, error)
  config :default_level, :validate => ['debug', 'info', 'warning', 'error', 'critical'] , :default => 'info'

  # Format for the Rollbar "message" or item title. In most cases you'll want to override this
  # and build up a message with specific fields from the event.
  config :format, :validate => :string, :default => "%{message}"

  # Rollbar API URL endpoint. You shouldn't need to change this.
  config :endpoint, :validate => :string, :default => 'https://api.rollbar.com/api/1/item/'

  def hash_recursive
    Hash.new do |hash, key|
      hash[key] = hash_recursive
    end
  end

  public
  def register
    require 'net/https'
    require 'uri'
    @rb_uri = URI.parse(@endpoint)
    @client = Net::HTTP.new(@rb_uri.host, @rb_uri.port)
    if @rb_uri.scheme == "https"
      @client.use_ssl = true
      @client.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
  end # def register

  public
  def receive(event)
    return unless output?(event)

    rb_item = hash_recursive
    rb_item['access_token'] = @access_token.value

    # We'll want to remove fields from data without removing them from the original event
    data = JSON.parse(event.to_json)
    
    #
    # If logstash has created 'rollbar' fields, we'll use those to populate the item...
    #
    if data['rollbar']
      merge_keys = %w{platform language framework context request person server client fingerprint title uuid level}
      merge_keys.each do |key|
        data['rollbar'][key] && rb_item['data'][key] = data['rollbar'][key]
      end
      data.delete('rollbar')
    end

    # ...then put whatever's left in 'custom'...
    rb_item['data']['custom'] = data

    # ...and finally override the top level fields that have a specific meaning
    rb_item['data']['timestamp'] = event.timestamp.to_i
    rb_item['data']['level'] ||= @default_level
    rb_item['data']['environment'] = @environment
    rb_item['data']['body']['message']['body'] = event.sprintf(@format)

    rb_item['data']['notifier']['name'] = 'logstash'
    rb_item['data']['notifier']['version'] = '0.1.0'

    @logger.debug("Rollbar Item", :rb_item => rb_item)

    begin
      request = Net::HTTP::Post.new(@rb_uri.path)
      request.body = JSON.dump(rb_item)
      @logger.debug("Rollbar Request", :request => request.body)
      response = @client.request(request)
      @logger.debug("Rollbar Response", :response => response.body)

    rescue Exception => e
      @logger.warn("Rollbar Exception", :rb_error => e.backtrace)
    end
  end # def receive
end # class LogStash::Outputs::Rollbar
