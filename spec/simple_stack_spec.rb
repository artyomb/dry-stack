# frozen_string_literal: true
# rubocop:disable Rspec/ExampleLength, Style/MixinUsage, Rspec/DescribeClass

include Dry

describe 'Test simple Stack' do
  it 'converts to compose' do
    ENV.delete_if { _1 =~/BUNDLE|DEBUG|IDE_PROCESS_DISPATCHER/ }

    Dir.chdir File.expand_path('data',__dir__) do
      Dir['stack*.drs'].each do |stack_file|
        drs = File.read(stack_file)
        Dry::Stack() { eval drs }
        puts "stack_file: #{stack_file}"

        stack = Stack.last_stack
        # CAN'T USE: The Options are applied only in CMD mode
        # stack_compose = Stack.last_stack.to_compose

        stack.instance_eval do ( [nil] + @configurations.keys )
        end.each do |configuration|
          cc = configuration ? "-c #{configuration}" : ''
          stack_compose_shell = "---\n" + `bundle exec ../bin/dry-stack -s #{stack_file} #{cc} to_compose` #  2> /dev/null

          sufix = configuration ? "-compose-#{configuration}.yml" : '-compose.yml'
          # expect(stack_compose).to eq(stack_compose_shell)
          compose = YAML.load_file stack_file.gsub('.drs', sufix), aliases: true rescue ''
          # puts stack_compose_shell

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
end

