require_relative 'command_line'

Dry::CommandLine::COMMANDS[:to_compose] = Class.new do
  def run(stack, params, args)
    yaml = stack.to_compose.lines[1..].join

    # substitute ENV variables
    params[:'no-env'] ? $stdout.puts(yaml) : system("echo \"#{yaml}\"")
  end

  def help = 'Print stack in docker compose format'
end.new

