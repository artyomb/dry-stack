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

      def safe_eval(str) = Dry::Stack() { eval str, self.binding }

      def run(args)
        params = {}

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
          COMMANDS.each { |name, cmd| o.separator "#{' ' * 5}#{name} -  #{cmd.help}" }

          o.separator ''
          o.separator 'Options:'

          #  in all caps are required
          o.on('-s', '--stack STACK_NAME', 'Stack file')
          o.on('-e', '--env', 'Load .env file') { load_env }
          o.on('',   '--name STACK_NAME', 'Define stack name')
          o.on('',   '--ingress', 'Generate ingress labels') { true }
          o.on('',   '--traefik', 'Generate traefik labels') { true }
          o.on('',   '--traefik_tls', 'Generate traefik tls labels') { true }
          o.on('',   '--host_sed /from/to/', 'Sed ingress host  /\\*/dev.*/')
          o.on('-n', '--no-env', 'Do not process env variables') { true }
          o.on('-h', '--help') { puts o; exit }
          o.parse! args, into: params

          raise 'Stack file not defined' if $stdin.tty? && !params[:stack]

          command = args.shift || ''
          raise "Unknown command: #{command}" unless COMMANDS.key?(command.to_sym)

          stack_text = File.read(params[:stack]) if params[:stack]
          stack_text ||= STDIN.read unless $stdin.tty?

          safe_eval stack_text # isolate context

          Stack.last_stack.name = params[:name] if params[:name]
          COMMANDS[command.to_sym].run Stack.last_stack, params
        rescue => e
          puts e.message
          ENV['DEBUG'] ? raise : exit(1)
        end
      end
    end
  end
end
