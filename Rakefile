require "rspec/core/rake_task"

rspec = RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new


task default: %i[rspec]

desc "CI Rspec run with reports"
task :rspec do |t|
  # rm "coverage.data" if File.exist?("coverage.data")
  rspec.rspec_opts = "--profile --color -f documentation -f RspecJunitFormatter --out ./results/rspec.xml"
  Rake::Task["spec"].invoke
end


# To RuboCop the current commit -
# git diff-tree --no-commit-id --name-only -r HEAD --diff-filter AMT | xargs bundle exec rubocop
# To RuboCop the working tree changes -
# git diff --name-only --diff-filter AMT | xargs bundle exec rubocop
# To RuboCop all of the changes from the branch -
# git diff --name-only master --diff-filter AMT | xargs bundle exec rubocop
