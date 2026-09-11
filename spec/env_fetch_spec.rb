# frozen_string_literal: true
# rubocop:disable Style/MixinUsage, RSpec/DescribeClass

include Dry

describe "ENV!" do
  around do |example|
    env = ENV.to_hash
    example.run
  ensure
    ENV.replace(env)
  end

  it "fetches an environment variable in the stack DSL" do
    ENV["DRY_STACK_ENV_BANG"] = "required-value"

    Stack("env_test") do
      Service :app, image: "app", env: { REQUIRED: ENV!["DRY_STACK_ENV_BANG"] }
    end

    compose = YAML.load(Dry::Stack.last_stack.to_compose, aliases: true)

    expect(compose.fetch("services").fetch("app").fetch("environment").fetch("REQUIRED")).to eq("required-value")
  end

  it "uses a default value for a missing environment variable" do
    ENV.delete("DRY_STACK_ENV_BANG_MISSING")

    Stack("env_test") do
      Service :app, image: "app", env: { OPTIONAL: ENV!["DRY_STACK_ENV_BANG_MISSING", "default value"] }
    end

    compose = YAML.load(Dry::Stack.last_stack.to_compose, aliases: true)

    expect(compose.fetch("services").fetch("app").fetch("environment").fetch("OPTIONAL")).to eq("default value")
  end

  it "raises KeyError when the environment variable is missing and no default is provided" do
    ENV.delete("DRY_STACK_ENV_BANG_MISSING")

    expect do
      Stack("env_test") do
        ENV!["DRY_STACK_ENV_BANG_MISSING"]
      end
    end.to raise_error(KeyError, /key not found/)
  end
end

# rubocop:enable Style/MixinUsage, RSpec/DescribeClass
