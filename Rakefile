require 'rspec/core/rake_task'
require_relative 'lib/version'

rspec = RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new


task default: %i[rspec]

desc 'CI Rspec run with reports'
task :rspec do |t|
  # rm "coverage.data" if File.exist?("coverage.data")
  rspec.rspec_opts = "--profile --color -f documentation -f RspecJunitFormatter --out ./results/rspec.xml"
  Rake::Task["spec"].invoke
end

require 'erb'

desc 'Update readme'
task :readme do |t|
  puts 'Update readme.erb -> readme.md'
  template = File.read './README.erb'
  renderer = ERB.new template, trim_mode: '-'
  File.write './README.md', renderer.result
end

desc 'Build&push new version'
task push: %i[rspec readme] do |t|
  puts 'Build&push new version'
  system 'gem build dry-stack.gemspec' or exit 1
  system "gem install ./dry-stack-#{Dry::Stack::VERSION}.gem" or exit 1
  # curl -u gempusher https://rubygems.org/api/v1/api_key.yaml > ~/.gem/credentials; chmod 0600 ~/.gem/credentials
  system "gem push dry-stack-#{Dry::Stack::VERSION}.gem" or exit 1
  system 'gem list -r dry-stack' or exit 1
end

# To RuboCop the current commit -
# git diff-tree --no-commit-id --name-only -r HEAD --diff-filter AMT | xargs bundle exec rubocop
# To RuboCop the working tree changes -
# git diff --name-only --diff-filter AMT | xargs bundle exec rubocop
# To RuboCop all of the changes from the branch -
# git diff --name-only master --diff-filter AMT | xargs bundle exec rubocop
