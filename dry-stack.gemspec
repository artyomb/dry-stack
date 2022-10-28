# lib = File.expand_path('lib', __dir__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
# require 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'dry-stack'
  s.version     = '0.0.1'
  s.executables << 'dry-stack'
  s.summary     = 'Dry docker swarm stack definition'
  s.description = ''
  s.authors     = ['Artyom B']
  s.email       = 'author@email.address'
  s.files       = Dir['{bin,lib,test}/**/*']
  # s.files         = Dir["CHANGELOG.md", "LICENSE", "README.md", "dry-stack.gemspec", "lib/**/*"]

  s.bindir        = 'bin'
  s.require_paths = ['lib']
  s.homepage    = 'https://rubygems.org/gems/dry-stack'
  s.license     = 'Nonstandard' # http://spdx.org/licenses
  s.metadata    = { 'source_code_uri' => 'https://github.com/artyomb/dry-stack' }

  s.required_ruby_version = ">= " + File.read(File.dirname(__FILE__)+'/.ruby-version').strip

  # s.add_runtime_dependency ''

  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.10"
  s.add_development_dependency "rubocop", "~> 1.12"
  s.add_development_dependency "rubocop-rake"
  s.add_development_dependency "rubocop-rspec"
  s.add_development_dependency "rspec_junit_formatter"
end
# http://guides.rubygems.org/make-your-own-gem
# gem build dry-stack.gemspec
# gem install ./dry-stack-0.0.0.gem
# curl -u gempusher https://rubygems.org/api/v1/api_key.yaml > ~/.gem/credentials; chmod 0600 ~/.gem/credentials
# gem push dry-stack-0.0.0.gem
# gem list -r dry-stack