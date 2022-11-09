gem build dry-stack.gemspec
gem install ./dry-stack-0.0.9.gem
#curl -u gempusher https://rubygems.org/api/v1/api_key.yaml > ~/.gem/credentials; chmod 0600 ~/.gem/credentials
gem push dry-stack-0.0.9.gem
gem list -r dry-stack