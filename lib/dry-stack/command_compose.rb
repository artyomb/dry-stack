require_relative 'command_line'

Dry::CommandLine::COMMANDS[:to_compose] = Class.new do
  def run(stack, params, _args, _extra)
    _params = stack.options.merge params
    yaml = stack.to_compose(_params ).lines[1..].join
    $stdout.puts yaml

    # substitute ENV variables
    # _params[:'no-env'] ? $stdout.puts(yaml) : system("echo \"#{yaml.gsub("`", '\\\`')}\"")
  end

  def help = ['Print stack in docker compose format',
              '[... to_compose <deploy name>] ']

end.new


