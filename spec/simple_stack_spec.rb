# frozen_string_literal: true
# rubocop:disable Rspec/ExampleLength, Style/MixinUsage, Rspec/DescribeClass

include Dry

describe 'Test simple Stack' do
  it 'converts to compose' do
    Dir[File.expand_path('data/*.drs', __dir__)].each do |stack_file|
      Dry::Stack() { eval File.read(stack_file) }

      puts Stack.last_stack.to_compose
      compose = YAML.load_file stack_file.gsub('.drs', '-compose.yml')

      expect(Stack.last_stack.to_compose).to eq(compose.to_yaml)
    end
  end
end

