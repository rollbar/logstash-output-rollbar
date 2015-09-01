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

  # Each of these config values can be specified in the plugin configuration section, in which
  # case they'll apply to all events, or you can override them on an event by event basis.
  #
  # Your default Rollbar access token. You can override this for a specific event by adding
  # a "[rollbar][access_token]" field to that event
  config :access_token, :validate => :password, :required => true

  # The default Rollbar environment. You can override this for a specific event by adding
  # a "[rollbar][environment]" field to that event
  config :environment, :validate => :string, :default => 'production'

  # The default level for Rollbar events (info, warning, error) You can override this for a specific
  # event by adding a "[rollbar][level]" field to that event
  config :level, :validate => ['debug', 'info', 'warning', 'error', 'critical'] , :default => 'info'

  # The default format for the Rollbar "message" or item title. In most cases you'll want to override
  # this and build up a message with specific fields from the event. You can override this for a specific
  # event by adding a "[rollbar][format]" field to that event.
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

    # We'll want to remove fields from data without removing them from the original event
    data = JSON.parse(event.to_json)
    
    #
    # If logstash has created 'rollbar' fields, we'll use those to populate the item...
    #
    if data['rollbar']

      merge_keys = %w{access_token client context environment fingerprint format framework
                      language level person platform request server title uuid }
      merge_keys.each do |key|
        data['rollbar'][key] && rb_item['data'][key] = data['rollbar'][key]
      end
      data.delete('rollbar')
    end

    # ...then put whatever's left in 'custom'...
    rb_item['data']['custom'] = data

    # ...and finally override the fields that have a specific meaning
    rb_item['data']['timestamp'] = event.timestamp.to_i
    rb_item['data']['level'] = @level unless rb_item['data'].has_key?('level')
    rb_item['data']['environment'] = @environment unless rb_item['data'].has_key?('environment')

    rb_item['data']['notifier']['name'] = 'logstash'
    rb_item['data']['notifier']['version'] = Gem.loaded_specs["logstash-output-rollbar"].version

    # Construct the message body using either:
    #
    # - The default format string defined above "%{message}"
    # - The format string specified in the rollbar plugin config section
    # - The format string specified in the [rollbar][format] event field
    #
    format = rb_item['data'].has_key?('format') ? rb_item['data']['format'] : @format
    rb_item['data']['body']['message']['body'] = event.sprintf(format)

    # Treat the [rollbar][access_token] field as a special case, since we don't need to
    # include it more than once in the Rollbar item
    #
    if rb_item['data'].has_key?('access_token')
      rb_item['access_token'] = rb_item['data']['access_token']
      rb_item['data'].delete('access_token')
    else
      rb_item['access_token'] = @access_token.value
    end


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
