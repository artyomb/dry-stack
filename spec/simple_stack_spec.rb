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

      compose = YAML.load_file stack_file.gsub('.drs', '-compose.yml'), aliases: true
      stack_compose = Stack.last_stack.to_compose
      stack_compose_shell = "---\n" + `bundle exec ./bin/dry-stack -s #{stack_file} -n to_compose` #  2> /dev/null

      expect(stack_compose).to eq(stack_compose_shell)

      # unless stack_compose == compose.to_yaml
      #   yaml = YAML.load stack_compose, aliases: true
      #   File.write stack_file.gsub('.drs', '-compose.yml'), yaml.to_yaml
      #   compose = YAML.load_file stack_file.gsub('.drs', '-compose.yml'), aliases: true
      # end
      expect(stack_compose).to eq(compose.to_yaml)

    end
  end
end

