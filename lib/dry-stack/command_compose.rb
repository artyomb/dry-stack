require_relative 'command_line'

Dry::CommandLine::COMMANDS[:to_compose] = Class.new do
  def run(stack, params, args, extra)
    raise "none or one deploy name may be specified: #{args}" unless args.empty? || args.size == 1
    _params = stack.options.merge params
    stack.name = _params[:name] if _params[:name]
    yaml = stack.to_compose(_params, args[0]&.to_sym ).lines[1..].join

    # substitute ENV variables
    _params[:'no-env'] ? $stdout.puts(yaml) : system("echo \"#{yaml.gsub("`", '\\\`')}\"")
  end

  def help = ['Print stack in docker compose format',
              '[... to_compose <deploy name>] ']

end.new


