#lib = File.expand_path('lib', __dir__)
#$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'dry-stack'
  s.version     = Dry::Stack::VERSION
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

  s.add_runtime_dependency 'bcrypt'

  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.10"
  s.add_development_dependency "rubocop", "~> 1.12"
  s.add_development_dependency "rubocop-rake", "~> 0.6.0"
  s.add_development_dependency "rubocop-rspec", "~> 2.14.2"
  s.add_development_dependency "rspec_junit_formatter", "~> 0.5.1"
end
