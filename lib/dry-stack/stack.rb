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
  end

  class Stack
    class << self
      attr_accessor :last_stack
    end

    def Stack(name = nil, &)
      Stack.last_stack = Stack.new name
      Stack.last_stack.instance_exec(&) if block_given?
    end

    def initialize(name)
      @name = name || 'stack'
      @services = {}
      @networks = {}
      @publish_ports = {}
      @ingress = {}
    end

    def stringify(hash) = hash.to_h { |k, v| [k.to_s, v.is_a?(Hash) ? stringify(v) : v] }

    def nginx_host2regexp(str)
      str.to_s.gsub('.', '\.').gsub('*', '.*')
    end

    def to_compose(opts = {})
      compose = {
        name: @name.to_s, # https://docs.docker.com/compose/compose-file/#name-top-level-element
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

        if @ingress[name] && (opts[:ingress] || opts[:traefik])
          service[:networks] ||= []
          service[:networks] << 'default' if service[:networks].empty?
          service[:networks] << 'ingress_routing'
        end

        if @ingress[name] && opts[:ingress]
          service[:deploy][:labels] = @ingress[name]&.map { |k, v| "ingress.#{k}=#{v}" }
        end

        if @ingress[name] && opts[:traefik]
          service_name = "#{@name}_#{name}"
          service[:deploy][:labels] += [
            'traefik.enable=true',
            "traefik.http.routers.nginx.service=#{service_name}",
            "traefik.http.services.#{service_name}.loadbalancer.server.port=#{@ingress[name][:port]}",
            "traefik.http.routers.nginx.rule=HostRegexp(`{name:#{nginx_host2regexp @ingress[name][:host]}}`)"
          ]
        end

        service[:ports] = @publish_ports[name]&.zip(service[:ports] || @publish_ports[name])&.map { _1.join ':' }
      end

      prune = ->(o) {
        o.each { prune[_2] }  if o.is_a? Hash
        o.delete_if { _2.nil? || (_2.respond_to?(:empty?) && _2.empty?) } if o.is_a? Hash
      }
      prune[compose]
      stringify(compose).to_yaml
    end

    def HttpFront(params)
      yield if block_given?
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

    def Ingress(services)
      @ingress.merge! services
    end

    def Network(name, opts = {})
      @networks[name] ||= {}
      @networks[name].merge! opts
      yield if block_given?
    end
  end
end

