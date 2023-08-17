# frozen_string_literal: true
require 'yaml'
require 'optparse'

module Dry

  def Stack(name = nil, &)
    Stack.last_stack = Stack.new name
    Stack.last_stack.instance_exec(&) if block_given?
  end

  class ServiceFunction
    def initialize(service, &); @service = service; instance_exec(&) end
    def env(variables)= @service[:environment].merge! variables
    def volume(opts)= ((@service[:volumes] ||= []) << opts).flatten!
    def image(name)= @service[:image] = name
    def ports(ports)= ((@service[:ports] ||= []) << ports).flatten!
    def command(cmd)= @service[:command] = cmd
    def entrypoint(cmd)= @service[:entrypoint] = cmd
    def deploy_label(str)= @service[:deploy][:labels] << str
  end

  class Stack
    COMPOSE_VERSION = '3.8'
    class << self
      attr_accessor :last_stack
    end
    attr_accessor :name, :options, :description

    def Stack(name = nil, &)
      Stack.last_stack = Stack.new name
      Stack.last_stack.instance_exec(&) if block_given?
    end

    def initialize(name)
      @name = name || 'stack'
      @version = COMPOSE_VERSION
      @description = ''
      @options = {}
      @services = {}
      @networks = {}
      @volumes = {}
      @publish_ports = {}
      @ingress = {}
      @deploy = {}
      @labels = {}
    end

    def stringify(obj)
      case
        when obj.is_a?(Hash); obj.to_h { |k, v| [k.to_s, stringify(v)] }
        when obj.is_a?(Array); obj.map { stringify(_1) }
        else obj
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

    def nginx_host2regexp(str)
      # http://nginx.org/en/docs/http/server_names.html
      if str[0] == '~'
        # ~^(?<user>.+)\.example\.net$;
        str[1..]
      else
        str.to_s.gsub('.', '\.').gsub('*', '.*')
      end
    end

    def to_compose(opts = @options )
      compose = {
        # name: @name.to_s, # https://docs.docker.com/compose/compose-file/#name-top-level-element
        # Not allowed by docker stack deploy
        version: @version,
        services: YAML.load(@services.to_yaml),
        volumes: YAML.load(@volumes.to_yaml),
        networks: YAML.load(@networks.to_yaml),
      }

      if @ingress.any?
        compose[:networks].merge! ingress_routing: {external: true, name: 'ingress-routing'}
      end

      compose[:services].each do |name, service|
        ingress = [@ingress[name]].flatten
        service[:deploy] ||= {}
        service[:deploy][:labels] ||= []
        service[:deploy][:labels] += @labels.map { "#{_1}=#{_2}" }

        if ingress[0] && (opts[:ingress] || opts[:traefik] || opts[:traefik_tls])
          service[:networks] ||= []
          service[:networks] << 'default' if service[:networks].empty?
          service[:networks] << 'ingress_routing'
        end

        ingress.each do |rule|
          if opts[:host_sed] && rule[:host]
            a, b = opts[:host_sed].split('/').reject(&:empty?)
            rule[:host].gsub! %r{#{a}}, b
          end
        end

        if ingress[0] && opts[:ingress]
          ingress[0][:port] ||= service[:ports]&.first
          service[:deploy][:labels] = ingress[0]&.map { |k, v| "ingress.#{k}=#{v}" }
        end

        service_name = "#{@name}_#{name}"

        if ingress[0] && (opts[:traefik] || opts[:traefik_tls])
          service[:deploy][:labels] << 'traefik.enable=true'

          ingress.each_with_index do |ing, index|
            ing[:port] ||= service[:ports]&.first
            service[:deploy][:labels] += [
              "traefik.http.routers.#{service_name}-#{index}.service=#{service_name}-#{index}",
              "traefik.http.services.#{service_name}-#{index}.loadbalancer.server.port=#{ing[:port]}"
            ]

            if opts[:traefik_tls]
              domain = opts[:tls_domain] || 'example.com'
              domain = @ingress[name][:host].gsub('.*', ".#{domain}") if @ingress[name][:host]
              domain = @ingress[name][:tls_domain] if @ingress[name][:tls_domain]
              service[:deploy][:labels] += [
                "traefik.http.routers.#{service_name}-#{index}.tls=true",
                "traefik.http.routers.#{service_name}-#{index}.tls.certresolver=le",
                "traefik.http.routers.#{service_name}-#{index}.tls.domains[0].main=#{domain}"
              ]
            end

            rule = []
            rule << "HostRegexp(`{name:#{nginx_host2regexp ing[:host]}}`)" if ing[:host]
            rule << "PathPrefix(`#{nginx_host2regexp ing[:path]}`)" if ing[:path]
            rule << "#{ing[:rule]}" if ing[:rule]

            service[:deploy][:labels] << "traefik.http.routers.#{service_name}-#{index}.rule=#{rule.join ' && '}"
          end
        end

        hash = {'service-name': service_name}
        hash.default = ''
        original_verbosity = $VERBOSE
        $VERBOSE = nil
        service[:deploy][:labels].map!{ _1 % hash }
        $VERBOSE = original_verbosity

        service[:deploy].merge! @deploy[name] if @deploy[name]

        pp_i = @publish_ports[name]&.reject { _1.class == String }
        pp_s = @publish_ports[name]&.select { _1.class == String }
        service[:ports] = pp_i&.zip(service[:ports] || pp_i)&.map { _1.join ':' }
        service[:ports] = (service[:ports] || []) + pp_s unless pp_s.nil?

        service[:environment].transform_values!{ !!_1 == _1 ? _1.to_s : _1 } # false | true to string
      end

      prune = ->(o) {
        o.each { prune[_2] }  if o.is_a? Hash
        o.delete_if { _2.nil? || (_2.respond_to?(:empty?) && _2.empty?) } if o.is_a? Hash
      }
      prune[compose]
      stringify(compose).to_yaml
    end

    def PublishPorts(ports)
      @publish_ports = ports.to_h { |k, v| [k,[v].flatten] }
    end

    def Service(name, opts = {}, &)
      opts[:ports] = [opts[:ports]].flatten if opts.key? :ports
      opts[:environment] = opts.delete(:env) if opts.key? :env

      @services[name] ||= {environment: {}, deploy: {labels: []}}
      @services[name].merge! opts
      ServiceFunction.new(@services[name], &)  if block_given?
    end

    def Description(string)
      @description = string
    end

    def Options(opts)
      warn 'WARN: Options command is used for testing purpose.\
            Not recommended in real life configurations.' unless $0 =~ /rspec/
      @options.merge! opts
    end

    def Labels(labels)
      @labels.merge! labels
    end

    def Ingress(services)
      @ingress.merge! services
    end

    def Deploy(services)
      @deploy.merge! expand_hash(services)
    end

    def Network(name, opts = {})
      @networks[name] ||= {}
      @networks[name].merge! opts
      yield if block_given?
    end

    def Volume(name, opts = {})
      @volumes[name] ||= {}
      @volumes[name].merge! opts
      yield if block_given?
    end
  end
end

