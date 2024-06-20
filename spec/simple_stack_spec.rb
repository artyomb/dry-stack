# frozen_string_literal: true
# rubocop:disable Rspec/ExampleLength, Style/MixinUsage, Rspec/DescribeClass

include Dry

describe 'Test simple Stack' do
  it 'converts to compose' do
    ENV.delete_if { _1 =~/BUNDLE|DEBUG|IDE_PROCESS_DISPATCHER/ }

    Dir[File.expand_path('data/*.drs', __dir__)].each do |stack_file|
      drs = File.read(stack_file)
      Dry::Stack() { eval drs }
      puts "stack_file: #{stack_file}"

      stack = Stack.last_stack
      # CAN'T USE: The Options are aplyied only in CMD mode
      # stack_compose = Stack.last_stack.to_compose

      stack.instance_eval do
        {'' => ''}.merge @swarm_deploy
      end.each do |deploy_name, _|
        stack_compose_shell = "---\n" + `bundle exec ./bin/dry-stack -s #{stack_file} -n to_compose #{deploy_name}` #  2> /dev/null

        sufix = deploy_name == '' ? '-compose.yml' : "-compose-#{deploy_name}.yml"
        # expect(stack_compose).to eq(stack_compose_shell)
        compose = YAML.load_file stack_file.gsub('.drs', sufix), aliases: true rescue ''

        # unless stack_compose_shell == compose.to_yaml
        #   yaml = YAML.load stack_compose_shell, aliases: true
        #   File.write stack_file.gsub('.drs', sufix), yaml.to_yaml
        #   compose = YAML.load_file stack_file.gsub('.drs', sufix), aliases: true
        # end
        expect(stack_compose_shell).to eq(compose.to_yaml)
      end
    end
  end
end

