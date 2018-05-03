Gem::Specification.new do |s|

  s.name            = 'logstash-output-rollbar'
  s.version         = '0.2.0'
  s.licenses        = ['Apache-2.0']
  s.summary         = "The Rollbar Logstash output sends events to the Rollbar error monitoring service."
  s.description     = "This gem is a logstash plugin. Install using: $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ["Rollbar"]
  s.email           = 'support@rollbar.com'
  s.homepage        = "https://github.com/rollbar/logstash-output-rollbar"
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)+::Dir.glob('vendor/*')

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency 'logstash-core', '~> 5.0', '>= 5.0.0'
  s.add_development_dependency 'logstash-devutils', '~> 1.3', '>= 1.3.6'
end

