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
      @name = name
      @services = {}
      @networks = {}
      @publish_ports = {}
      @ingress = {}
    end

    def stringify(hash) = hash.to_h { |k, v| [k.to_s, v.is_a?(Hash) ? stringify(v) : v] }

    def to_compose
      compose = {name: @name,
                 services: YAML.load(@services.to_yaml),
                 networks: YAML.load(@networks.to_yaml),
      }

      compose[:services].each do |name, service|
        @ingress[name][:port] ||= service[:ports]&.first if @ingress[name]
        service[:deploy] ||= {}
        service[:deploy][:labels] = @ingress[name]&.map { |k, v| "ingress.#{k}=#{v}" }

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

