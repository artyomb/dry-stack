require_relative 'command_line'

Dry::CommandLine::COMMANDS[:swarm_deploy] = Class.new do
  def run(stack, params)
    _params = stack.options.merge params
    stack.name = _params[:name] if _params[:name]
    yaml = stack.to_compose(_params).lines[1..].join

    # substitute ENV variables
    yaml = _params[:'no-env'] ? yaml : `echo \"#{yaml.gsub("`", '\\\`')}\"`
    system " echo \"#{yaml.gsub("`", '\\\`')}\"" if _params[:v]
    system " echo \"#{yaml.gsub("`", '\\\`')}\" | docker stack deploy -c - #{stack.name} --prune --resolve-image changed"
  end

  def help = 'Call docker stack deploy'
end.new


