require_relative '../version'
require 'open3'

def exec_i(cmd, input_string = nil)
  puts "exec_i(inputs.size #{input_string&.size}): #{cmd}"
  Open3.popen3(cmd) do |i, o, e, wait_thr|
    i.puts input_string unless input_string.nil?
    i.close
    while line = o.gets; puts "o: " + line end
    while line = e.gets; puts "o: " + line end
    return_value = wait_thr.value
    puts "Error level was: #{return_value.exitstatus}" unless return_value.success?
    exit return_value.exitstatus unless return_value.success?
  end
end

def exec_o_lines(cmd,&)
  IO.popen(cmd, 'r') do |f|
    f.each_line do |line|
      yield line
    end
  end
end

module Dry
  module CommandLine
    COMMANDS = {}

    class << self
      def load_env
        File.read('.env').lines.map(&:strip).grep_v(/^\s*#/).reject(&:empty?)
          .map {_1.split('=').map(&:strip).tap { |k,v|
            ENV[k] = v
          }}.to_h
       rescue =>e
         puts "Load env error: #{e.message}"
         raise 'Invalid .env file'
      end

      def safe_eval(drs, params)
        Dry::Stack(params[:name], params[:configuration]) { eval drs, self.binding }
      end

      def run(args)
        params = {}

        a, extra = ARGV.join(' ').split( / -- /)
        ARGV.replace a.split if a
        ARGV << '-h' if ARGV.empty?

        OptionParser.new do |o|
          o.version = "#{Dry::Stack::VERSION}"

          usage = [
            'dry-stack -s stackfile [options] COMMAND',
            'cat stackfile | dry-stack COMMAND',
            'dry-stack COMMAND < stack.drs'
          ]
          o.banner = "Version: #{o.version}\nUsage:\n\t#{usage.join "\n\t"}"
          o.separator ''
          o.separator 'Commands:'
          COMMANDS.each { |name, cmd| o.separator "#{' ' * 5}#{name} -  #{[cmd.help].flatten.join "\n#{' ' * (5+4 + name.size)}" }" }

          o.separator ''
          o.separator 'Options:'

          #  in all caps are required
          o.on('-s', '--stack STACK_NAME', 'Stack file')
          o.on('-e', '--env', 'Load .env file') { load_env }
          o.on('',   '--name STACK_NAME', 'Define stack name')
          o.on('',   '--ingress', 'Generate ingress labels') { true }
          o.on('',   '--traefik', 'Generate traefik labels') { true }
          o.on('',   '--traefik-tls', 'Generate traefik tls labels') { true }
          o.on('',   '--tls-domain domain', 'Domain for the traefik labels')
          o.on('',   '--host-sed /from/to/', 'Sed ingress host  /\\*/dev.*/')
          o.on('-n', '--no-env', 'Deprecated') { $stderr.puts 'warning: deprecated option: -n' } # TODO: remove
          o.on('-c', '--configuration name', 'Configuration name')
          COMMANDS.values.select{_1.options(o) if _1.respond_to? :options }

          o.on('-h', '--help') { puts o; exit }
          o.parse! args, into: params

          params.transform_keys!{_1.to_s.gsub('-','_').to_sym}
          params[:traefik_tls] = true if params[:tls_domain]

          raise 'Stack file not defined' if $stdin.tty? && !params[:stack]

          command = args.shift || ''
          raise "Unknown command: #{command}" unless COMMANDS.key?(command.to_sym)

          stack_text = File.read(params[:stack]) if params[:stack]
          stack_text ||= STDIN.read unless $stdin.tty?


          safe_eval stack_text, params # isolate context

          Stack.last_stack.name = params[:name] if params[:name]
          COMMANDS[command.to_sym].run Stack.last_stack, params, args, extra
        rescue => e
          puts e.message
          ENV['DEBUG'] ? raise : exit(1)
        end
      end
    end
  end
end
