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
    def image(name)= @service[:image] = name
    def ports(ports)= ((@service[:ports] ||= []) << ports).flatten!
    def command(cmd)= @service[:command] = cmd
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
      @publish_ports = {}
      @ingress = {}
      @deploy = {}
    end

    def stringify(hash) = hash.to_h { |k, v| [k.to_s, v.is_a?(Hash) ? stringify(v) : v] }
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
        networks: YAML.load(@networks.to_yaml),
      }

      if @ingress.any?
        compose[:networks].merge! ingress_routing: {external: true, name: 'ingress-routing'}
      end

      compose[:services].each do |name, service|
        @ingress[name][:port] ||= service[:ports]&.first if @ingress[name]
        service[:deploy] ||= {}
        service[:deploy][:labels] ||= []

        if @ingress[name] && (opts[:ingress] || opts[:traefik] || opts[:traefik_tls])
          service[:networks] ||= []
          service[:networks] << 'default' if service[:networks].empty?
          service[:networks] << 'ingress_routing'
        end

        if opts[:host_sed] && @ingress.dig(name,:host)
          a, b = opts[:host_sed].split('/').reject(&:empty?)
          @ingress[name][:host].gsub! %r{#{a}}, b
        end

        if @ingress[name] && opts[:ingress]
          service[:deploy][:labels] = @ingress[name]&.map { |k, v| "ingress.#{k}=#{v}" }
        end

        if @ingress[name] && (opts[:traefik] || opts[:traefik_tls])
          service_name = "#{@name}_#{name}"

          service[:deploy][:labels] += [
            'traefik.enable=true',
            "traefik.http.routers.#{service_name}.service=#{service_name}",
            "traefik.http.services.#{service_name}.loadbalancer.server.port=#{@ingress[name][:port]}",
          ]

          if opts[:traefik_tls]
            service[:deploy][:labels] += [
              "traefik.http.routers.#{service_name}.entrypoints=http",
              "traefik.http.routers.#{service_name}.middlewares=service_stack-https-redirect",
              "traefik.http.routers.#{service_name}.entrypoints=https",
              "traefik.http.routers.#{service_name}.tls=true",
              "traefik.http.routers.#{service_name}.tls.certresolver=le"
            ]
          end

          rule = []
          rule << "HostRegexp(`{name:#{nginx_host2regexp @ingress[name][:host]}}`)" if @ingress[name][:host]
          rule << "PathPrefix(`#{nginx_host2regexp @ingress[name][:path]}`)" if @ingress[name][:path]
          rule << "#{@ingress[name][:rule]}" if @ingress[name][:rule]
          service[:deploy][:labels] << "traefik.http.routers.#{service_name}.rule=#{rule.join ' && '}"
        end

        service[:deploy].merge! @deploy[name] if @deploy[name]

        service[:ports] = @publish_ports[name]&.zip(service[:ports] || @publish_ports[name])&.map { _1.join ':' }
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

      @services[name] ||= {environment: {}}
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
  end
end

