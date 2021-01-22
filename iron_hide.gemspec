# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'iron_hide/version'

Gem::Specification.new do |spec|
  spec.name          = 'cnfs-iron_hide'
  spec.version       = IronHide::VERSION
  spec.authors       = ['Robert Roach', 'Alan Cohen']
  spec.email         = ['rjayroach@gmail.com', 'acohen@climate.com']
  spec.description   = 'A Ruby authorization library'
  spec.summary       = 'Describe your authorization rules with JSON'
  spec.homepage      = 'http://github.com/cnfs.io/iron_hide'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.rb']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'json_minify', '~> 0.2'
  spec.add_runtime_dependency 'multi_json'

  spec.add_development_dependency 'bundler', '~> 2'
  spec.add_development_dependency 'rake', '~> 13'
  spec.add_development_dependency 'rspec', '~> 3'
  # spec.add_development_dependency 'yard', '~> 0'
  spec.add_development_dependency 'pry'
end
