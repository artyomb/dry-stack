require_relative 'command_line'

Dry::CommandLine::COMMANDS[:swarm_deploy] = Class.new do
  def run(stack, params, args)
    unless args.empty?
      raise "deploy config not found: #{args[0]}" unless stack.swarm_deploy.key? args[0].to_sym
      context = stack.swarm_deploy[args[0].to_sym]
    end
    _params = stack.options.merge params
    stack.name = _params[:name] if _params[:name]

    if context
      name = context[:context_name]&.to_sym || args[0].to_sym
      host = context[:context_host]
      contexts = {}
      exec_o_lines "docker context ls --format json" do |line|
        ctx = JSON.parse line, symbolize_names: true
        contexts[ctx[:Name].to_sym] = ctx # {"Current":false,"Description":"","DockerEndpoint":"ssh://root@x.x.x.x","Error":"","Name":"prod-swarm"}
      end

      if contexts[name] && contexts[name][:DockerEndpoint] != host
        raise "context '#{name}' has different host value: #{contexts[name][:DockerEndpoint]} != #{host}"
      end

      exec_i "docker context create #{name} --docker host=#{host}" unless contexts[name]

      ENV['DOCKER_CONTEXT'] = name.to_s
      stack.name = context[:stack_name] || stack.name
      context[:stack_name][:environment].each do |k,v|
        ENV[k.to_s] = v.to_s
      end
    end

    # substitute ENV variables
    yaml = stack.to_compose(_params).lines[1..].join
    yaml = _params[:'no-env'] ? yaml : `echo \"#{yaml.gsub("`", '\\\`')}\"`
    system " echo \"#{yaml.gsub("`", '\\\`')}\"" if _params[:v]
    # system " echo \"#{yaml.gsub("`", '\\\`')}\" | docker stack deploy -c - #{stack.name} --prune --resolve-image changed"

    exec_i "docker stack deploy -c - #{stack.name} --prune  --resolve-image changed", yaml
    system "docker config rm $(docker config ls --filter label=com.docker.stack.namespace=#{stack.name} --format \"{{.ID}}\")"

    exec_i "docker config rm #{stack.name}_readme || echo 'failed to remove config #{stack.name}_readme'"
    puts "stack description: #{stack.description}"
    exec_i "docker config create #{stack.name}_readme -", stack.description
  end

  def help = 'Call docker stack deploy & add config readme w/ description'
end.new


