require_relative 'command_line'

Dry::CommandLine::COMMANDS[:swarm_deploy] = Class.new do
  def options(parser)
    parser.on('-x', '--context-endpoint host', 'Docker context host. Created if not exists')
  end

  def run(stack, params, args, extra)
    _params = stack.options.merge params
    stack.name = _params[:name] if _params[:name]

    raise 'Context endpoint required' unless params[:context_endpoint]

    name = params[:context_endpoint].gsub( /[\/.:@]/,'_').gsub( '__','_')
    name = "dry-#{name}".to_sym
    endpoint = params[:context_endpoint]
    $stdout.puts "Looking for docker context '#{name}'"

    contexts = {}
    exec_o_lines 'docker context ls --format json' do |line|
      ctx = JSON.parse line, symbolize_names: true
      contexts[ctx[:Name].to_sym] = ctx # {"Current":false,"Description":"","DockerEndpoint":"ssh://root@x.x.x.x","Error":"","Name":"prod-swarm"}
    end

    if contexts[name] && contexts[name][:DockerEndpoint] != endpoint
      raise "context '#{name}' has different host value: #{contexts[name][:DockerEndpoint]} != #{endpoint}"
    end

    unless contexts[name]
      system "docker context create #{name} --docker host=#{endpoint}"
      # exec_i "docker context create #{name} --docker host=#{endpoint}" do |return_value, _o, e|
      #   exit return_value.exitstatus unless return_value.success? || e !~ /already exists/m
      # end
    end

    ENV['DOCKER_CONTEXT'] = name.to_s

    # substitute ENV variables
    yaml = stack.to_compose(_params).lines[1..].join
    # system " echo \"#{yaml.gsub("`", '\\\`')}\" | docker stack deploy -c - #{stack.name} --prune --resolve-image changed"

    #  --prune  --resolve-image changed
    exec_i "docker --context #{name} stack deploy -c - --with-registry-auth #{extra} #{stack.name}", yaml
    # Hide messages like:
    # Error response from daemon: rpc error: code = InvalidArgument desc = config 'grafana_dashboards_yaml-206a34dc77dc394d78a207c7abde327d' is in use by the following service: grafana_grafana
    conf_list = `docker config ls --filter label=com.docker.stack.namespace=#{stack.name} --format \"{{.ID}}\"`
    unless conf_list.strip.empty?
      system "docker --context #{name} config rm $(docker config ls --filter label=com.docker.stack.namespace=#{stack.name} --format \"{{.ID}}\") 2>&1 | grep -v \"is in use\""
    end

    exec_i "docker --context #{name} config rm #{stack.name}_readme || echo 'failed to remove config #{stack.name}_readme'"
    puts "stack description: #{stack.description}"
    exec_i "docker --context #{name} config create #{stack.name}_readme -", stack.description
  end

  def help = ['Call docker stack deploy & add config readme w/ description',
              '[... swarm_deploy -- --prune  --resolve-image changed]']

end.new


