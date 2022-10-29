# frozen_string_literal: true
require 'yaml'
require 'optparse'

module Dry

  def Stack(name, &)
    Stack.last_stack = Stack.new name
    Stack.last_stack.instance_exec(&) if block_given?
  end

  class ServiceFunction
    def initialize(service, &); @service = service; instance_exec(&) end
    def env(variables)= @service[:environment].merge! variables
  end

  class Stack
    class << self
      attr_accessor :last_stack
    end

    def initialize(name)
      @name = name
      @services = {}
      @networks = {}
      @publish_ports = {}
    end

    def stringify(hash) = hash.to_h { |k, v| [k.to_s, v.is_a?(Hash) ? stringify(v) : v] }

    def to_compose
      compose = {name: @name,
                 services: YAML.load(@services.to_yaml),
                 networks: YAML.load(@networks.to_yaml),
      }

      compose[:services].each do |name, service|
        service[:ports] = @publish_ports[name]&.zip(service[:ports])&.map { _1.join ':' }
        service.delete_if { _2.nil? || _2.empty? }
      end

      compose.delete_if { _2.nil? || _2.empty? }
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

    def Network(name, opts = {})
      @networks[name] ||= {}
      @networks[name].merge! opts
      yield if block_given?
    end
  end
end

