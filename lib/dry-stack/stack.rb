# frozen_string_literal: true
require 'yaml'
require 'json'
require 'optparse'
require 'digest'
require_relative 'apache_specific_md5'

# class TrueClass
#   def encode_with(coder) = coder.represent_scalar('tag:yaml.org,2002:str', 'true')
# end
#
# class FalseClass
#   def encode_with(coder)= coder.represent_scalar('tag:yaml.org,2002:str', 'false')
# end

module Dry
  EMPTY_HASH = :empty_hash
  DEFAULT_INIT_SERVICE = true # add "init: true" option

  class ::Hash
    def deep_merge!(second)
      merger = proc { |_, v1, v2|
        if Hash === v1 && Hash === v2
          v1.merge!(v2, &merger)
        else
          if Array === v1 && Array === v2
            v1 | v2
          else
            [:undefined, nil, :nil].include?(v2) ? v1 : v2
          end
        end
      }
      merge!(second.to_h, &merger)
    end
  end

  def each_recursive(parent, each_ = -> { _1.respond_to?(:each) ? _1.each : [] }, path = [], &blk)
    each2_ = each_.is_a?(Array) ? ->(p) { (m = each_.find { p.respond_to? _1 }) ? p.send(m) : [] } : each_
    (each2_[parent] || []).each do |(k,v)|
      blk.call [path + [parent], k, v, path]
      each_recursive(v || k, each_, path + [parent], &blk)
    end
  end

  def expand_hash(hash)
    hash.select { _1.to_s =~ /\./ }.each do |k, v|
      name = k.to_s.scan(/([^\.]*)\.(.*)/).flatten
      hash.delete k
      hash[name[0]] ||= {}
      hash[name[0]][name[1]] ||= {}
      hash[name[0]][name[1]].merge! v if v.is_a?(Hash)
      hash[name[0]][name[1]] = v unless v.is_a?(Hash)
    end
    hash.each { expand_hash(_2) if _2.is_a?(Hash) }
    hash
  end

  attr_accessor :cmd_params
  @cmd_params = {}

  def Stack(name = nil, configuration = nil, &)
    Stack.last_stack = Stack.new name
    Stack.last_stack.instance_exec(&) if block_given?
    Stack.last_stack.instance_exec do
      @services_blocks&.each { instance_exec &_1 }
      @after_blocks&.each { instance_exec &_1 }
    end
    Stack.last_stack.apply_configuration configuration if configuration
  end

  class ServiceFunction
    def initialize(service, &); @service = service; instance_exec(&) end
    def env(variables)= @service[:environment].merge! variables
    def dns(dns)= ((@service[:dns] ||= []) << dns).flatten!
    def volume(opts)= ((@service[:volumes] ||= []) << opts).flatten!
    def image(name)= @service[:image] = name
    def ports(ports)= ((@service[:ports] ||= []) << ports).flatten!
    def command(cmd)= @service[:command] = cmd
    def entrypoint(cmd)= @service[:entrypoint] = cmd
    def deploy_label(str)= @service[:deploy][:labels] << str
    def deploy(opts)=@service[:deploy].merge! expand_hash(opts)
    def config(name = nil, opts)= (@service[:configs] ||= []) << {source: name.to_s}.merge(opts)
    def logging(opts) = (@service[:logging] ||= {}).merge!  opts
    def user(user) = @service[:user] = user #  "${UID}:${GID}", "www-data:www-data"
    def network(name, opts = {}) = (@service[:networks][name] ||={}).merge! opts
    def ingress(ing) = ((@service[:ingress] ||=[]) << ing).flatten!
  end

  class ConfigurationFunction
    def initialize(configuration, &); @configuration = configuration; instance_exec(&) end
  end

  class Stack
    COMPOSE_VERSION = '3.8'
    class << self
      attr_accessor :last_stack
    end
    attr_accessor :name, :options, :description, :configuration

    def Stack(...) = Dry::Stack(...)

    # def self.new(*args, &block)
    #   super
    # end

    def initialize(name)
      @name = name || 'stack'
      @version = COMPOSE_VERSION
      @description = ''
      @options = {}
      @services = {}
      @networks = {}
      @volumes = {}
      @environment = {}
      @publish_ports = {}
      @ingress = {}
      @deploy = {}
      @labels = {}
      @configs = {}
      @logging = {}
      @configurations = {}
    end

    def nginx_host2regexp(str)
      # http://nginx.org/en/docs/http/server_names.html
      if str[0] == '~'
        # ~^(?<user>.+)\.example\.net$;
        str[1..]
      else
        str.to_s.gsub('.', '\.').gsub('*', '.*')
      end
    end

    def apply_configuration(configuration)
      raise "Configuration not found: #{configuration}" unless @configurations[configuration.to_sym]
      @configurations[configuration.to_sym][:block_function].call
    end

    def to_compose(opts = @options)
      @name = @options[:name] || @name

      compose = {
        # name: @name.to_s, # https://docs.docker.com/compose/compose-file/#name-top-level-element
        # Not allowed by docker stack deploy
        version: @version,
        services: YAML.load(@services.to_yaml, aliases: true),
        volumes: YAML.load(@volumes.to_yaml, aliases: true),
        networks: YAML.load(@networks.to_yaml, aliases: true),
        configs: YAML.load(@configs.to_yaml, aliases: true)
      }

      compose[:services].each do |name, service|

        service[:image].gsub!(/:latest$/, '') if service[:image] # let docker swarm to create tag: :latest@sha265:0000...

        ingress = [@ingress[name], service[:ingress] || [] ].flatten.compact

        if ingress.any?
          compose[:networks].merge! ingress_routing: {external: true, name: 'ingress-routing'}
        end

        service[:deploy] ||= {}
        service[:deploy][:labels] ||= []
        service[:deploy][:labels] += @labels.map { "#{_1}=#{_2}" }

        if ingress[0] && (opts[:ingress] || opts[:traefik] || opts[:traefik_tls])
          service[:networks] ||= {}
          service[:networks][:default] ||= {} if service[:networks].empty?
          service[:networks][:ingress_routing] ||= {}
        end

        ingress.each do |rule|
          if opts[:host_sed] && rule[:host]
            a, b = opts[:host_sed].split('/').reject(&:empty?)
            rule[:host].gsub! %r{#{a}}, b
          end
        end

        service_name = "#{@name}_#{name}"

        if ingress[0] && (opts[:traefik] || opts[:traefik_tls])
          service[:deploy][:labels] << 'traefik.enable=true'
          ingress[0][:port] ||= service[:ports]&.first

          ingress.each_with_index do |ing, index|
            ing[:port] ||= service[:ports]&.first
            service[:deploy][:labels] += [
              "traefik.http.routers.#{service_name}-#{index}.service=#{service_name}-#{index}",
              "traefik.http.services.#{service_name}-#{index}.loadbalancer.server.port=#{ing[:port]}"
            ]

            if opts[:traefik_tls]
              domain = opts[:tls_domain] || 'example.com'
              domain = ing[:host].gsub('.*', ".#{domain}") if ing[:host]
              domain = ing[:tls_domain] if ing[:tls_domain]
              service[:deploy][:labels] += [
                "traefik.http.routers.#{service_name}-#{index}.tls=true",
                "traefik.http.routers.#{service_name}-#{index}.tls.certresolver=le",
                "traefik.http.routers.#{service_name}-#{index}.tls.domains[0].main=#{domain}"
              ]
            end

            rule = []
            rule << "HostRegexp(`{name:#{nginx_host2regexp ing[:host]}}`)" if ing[:host]
            rule << "ClientIP(#{[ing[:client_ip]].flatten.map{ "`#{_1}`" }.join ','})" if ing[:client_ip]
            rule << "PathPrefix(`#{ing[:path]}`)" if ing[:path]
            rule << "#{ing[:rule]}" if ing[:rule]

            middlewares = []

            if ing[:basic_auth]
              ba_user, ba_password, salt = ing[:basic_auth].split ':'
              hashed_password = apr1_crypt ba_password, (salt || rand(36**8).to_s(36))
              service[:deploy][:labels] << "traefik.http.middlewares.#{service_name}-#{index}_auth.basicauth.users=#{ba_user}:#{hashed_password.gsub('$','$$')}"
              middlewares << "#{service_name}-#{index}_auth"
            end

            service[:deploy][:labels] << "traefik.http.routers.#{service_name}-#{index}.rule=#{rule.join ' && '}"

            if ing[:path_sub]
              middlewares << "#{service_name}-#{index}-path_sub"
              service[:deploy][:labels] += [
                "traefik.http.middlewares.#{service_name}-#{index}-path_sub.replacepathregex.regex=#{ing[:path_sub][0]}",
                "traefik.http.middlewares.#{service_name}-#{index}-path_sub.replacepathregex.replacement=#{ing[:path_sub][1].gsub('$','$$')}"
              ]
            end

            service[:deploy][:labels] << "traefik.http.routers.#{service_name}-#{index}.middlewares=#{middlewares.join ","}" unless middlewares.empty?
          end
        end
        service.delete :ingress

        service[:environment] = @environment[name].merge(service[:environment])  if @environment[name]
        service[:environment].merge! STACK_NAME: @name.to_s, STACK_SERVICE_NAME: name.to_s
        service[:environment].transform_values! { !!_1 == _1 ? _1.to_s : _1 } # (false|true) to string

        service[:deploy].deep_merge! @deploy[name] if @deploy[name]

        # hash = {'service-name': service_name, 'stack-name': @name}
        env_sub = ->(s) {
          s = s.to_s.dup
          s.gsub!('%{stack-name}', @name.to_s)
          s.gsub!('%{service-name}', service_name)
          s
        }
        service[:deploy][:labels] = service[:deploy][:labels].map{ env_sub[_1] }
        service[:environment].transform_values!{ _1.is_a?(String) ? (env_sub[_1]) : _1 }

        pp_i = @publish_ports[name]&.reject { _1.class == String }
        pp_s = @publish_ports[name]&.select { _1.class == String }
        service[:ports] = pp_i&.zip(service[:ports] || pp_i)&.map { _1.join ':' }
        service[:ports] = (service[:ports] || []) + pp_s unless pp_s.nil?

        service[:logging] ||= @logging[name.to_sym]

        service[:volumes]&.map!&.with_index do |volume, index|
          if volume.is_a? Hash
            if volume.key?(:name) && volume.key?(:source)
              $stderr.puts 'Use either :name or :source in volume declaration as a Hash'
              $stderr.puts ':name will create Volume section automatically'
              raise 'invalid volume declaration'
            end
            unless volume.key? :source
              v_name = (volume[:local_name] || "#{service_name}-volume-#{index}").to_sym
              compose[:volumes][v_name] ||= {}
              compose[:volumes][v_name].merge! volume.slice(:name, :driver, :driver_opts, :labels)
              compose[:volumes][v_name][:external] = false if compose[:volumes][v_name].empty?
              volume[:type] ||= 'volume'
              volume.except(:name, :driver, :driver_opts, :local_name).merge source: v_name
            else
              volume
            end
          else
            volume
          end
        end

        service[:networks]&.each do |name, network|
          # raise "network name is invalid: #{name}" unless name.is_a? String, Symbol # https://bugs.ruby-lang.org/issues/20793
          raise "network name is invalid: #{name}" unless name in String | Symbol
          next unless network.is_a? Hash

          (compose[:networks][name] ||= {}).merge! network.except(:aliases)
          compose[:networks][name].merge(name: network[:name]) if network[:name]
          network.delete :external
          network.delete :name
          network.delete :attachable

          service[:networks][name] = EMPTY_HASH if network.empty?
        end

        service[:configs]&.each_with_index do |config, index|
          config[:source] = "#{service_name}-config-#{index}" if config[:source].to_s.empty?
          compose[:configs][config[:source].to_sym] ||= {}
          compose[:configs][config[:source].to_sym].merge! config.except(:source, :target)
          config.replace config.except :file_content, :file, :name
        end
      end

      compose[:configs].update(compose[:configs]) do |name, config|
        # total config name must be max 64 characters length. MD5 - 32 characters
        short_name = name[0..30]

        if config[:file_content]
          md5 = Digest::MD5.hexdigest config[:file_content]
          fname = "./#{@name}.config.#{name}.#{md5}" # use MD5, when run in parallel may have different content
          File.write fname, config[:file_content]
          {name: "#{short_name}-#{md5}", file: fname}.merge config.except(:file_content)
        elsif config[:file]
          body = File.read config[:file] rescue ''
          md5 = Digest::MD5.hexdigest body
          {name: "#{short_name}-#{md5}", file: fname}.merge config
        else
          config
        end
      end

      compose[:networks].delete_if{ |k,v| k == :default && v.empty? }
      compose[:networks].transform_values! do |network|
        network.empty? ? EMPTY_HASH : network
      end

      prune = ->(o) {
        o.each { prune[_2] }  if o.is_a? Hash
        o.delete_if { _2.nil? || ( _2.respond_to?(:empty?) && _2.empty?) } if o.is_a? Hash
      }
      prune[compose]

      each_recursive _root: compose do |_path, node, v|

        v.transform_keys!(&:to_s) if v.is_a? Hash
        node.transform_keys!(&:to_s) if node.is_a? Hash
        _path.last[node] = v.to_s if v.is_a? Symbol
        _path.last[node] = nil if v == EMPTY_HASH

        _path.last[node] = v.to_s if node.to_s == 'fluentd-async'
      end

      # compose.to_yaml
      JSON.parse(compose.to_json).to_yaml
    end

    def Include(file_name)
      dir = Dry.cmd_params[:stack] ? File.dirname(Dry.cmd_params[:stack]) : '.'
      eval IO.read( File.join dir, file_name )
    end

    def After(&block)
      (@after_blocks ||=[]) << block
    end

    def BeforeService(name = nil, opts = {}, &block)
      (@before_blocks ||=[]).push names: [name].flatten.compact, except: opts[:except],
                                  block: ->(s_name) {
        _ServiceImplementation s_name, opts, &block
      }
    end

    def AfterService(name = nil, opts = {}, &block)
      After do
        names = [name || @services.keys].flatten
        names -= [opts[:except]].flatten if opts.key? :except
        names.each do |s_name|
          _ServiceImplementation s_name, opts, &block
        end
      end
    end

    def PublishPorts(ports)
      @publish_ports.merge! ports.to_h { |k, v| [k,[v].flatten] }
    end

    def Service(name, opts = {}, &block)
      @services_blocks ||=[]
      (@services_blocks ||=[]).push -> { _ServiceDeferred(name, opts, &block) }
    end

    def _ServiceDeferred(name, opts = {}, &block)
      (@before_blocks || []).each do |before|
        next unless before[:names].empty? || before[:names].include?(name)
        next if before[:except]&.include? name
        before[:block].call(name)
      end
      _ServiceImplementation(name, opts, &block)
    end

    def _ServiceImplementation(name, opts = {}, &)
      opts = opts.dup
      opts[:ports] = [opts[:ports]].flatten if opts.key? :ports
      opts[:environment] = opts.delete(:env) if opts.key? :env

      service = @services[name.to_sym] ||= begin
        s = {environment: {}, deploy: {labels: []}, networks: {}}
        DEFAULT_INIT_SERVICE ? s.merge(init: true) : s
      end

      service.deep_merge! opts
      ServiceFunction.new(service, &) if block_given?
    end

    def Description(string)
      @description = string
    end

    def Options(opts)
      # warn 'WARN: Options command is used for testing purpose.\
      #       Not recommended in real life configurations.' unless $0 =~ /rspec/
      @options.merge! opts
    end

    def Labels(labels)
      @labels.merge! labels
    end

    def Ingress(services)
      services.each do |name, ing|
        @ingress[name] = ((@ingress[name] || [] ) | [ing]).flatten
      end
    end

    def Config(name, opts)
      @configs[name] = opts
    end

    def Deploy(names = nil, services)
      if names
        [names].flatten.each do |name|
          (@deploy[name.to_sym] ||= {}).merge! expand_hash(services)
        end
      else
        @deploy.merge! expand_hash(services)
      end
    end

    def Environment(names = nil, envs)
      if names
        [names].flatten.each do |name|
          (@environment[name.to_sym] ||= {}).merge! envs
        end
      else
        @environment.merge! envs
      end
    end

    def Network(name, opts = {})
      @networks[name] ||= {}
      @networks[name].merge! opts
      yield if block_given?
    end

    def Logging(names = nil, opts )
      if names
        [names].flatten.each do |name|
          (@logging[name.to_sym] ||= {}).merge! expand_hash(opts)
        end
      else
        @logging.merge! expand_hash(opts)
      end
    end

    def Volume(name, opts = {})
      @volumes[name] ||= {}
      @volumes[name].merge! opts
      yield if block_given?
    end

    def Configuration(name, opts = {}, &b)
      configuration = @configurations[name.to_sym] ||= {}
      configuration.merge! opts
      configuration.merge! block_function: -> {
        instance_exec(&b) if block_given? # https://rubyreferences.github.io/rubychanges/3.3.html#anonymous-parameters-forwarding-inside-blocks-are-disallowed
      }
    end

  end
end

