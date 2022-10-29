require_relative 'command_line'

Dry::CommandLine::COMMANDS[:compose] = Class.new do
  def run(stack, args)
    $stdout.puts stack.to_compose
  end

  def help = 'Print stack in docker compose format'
end.new


