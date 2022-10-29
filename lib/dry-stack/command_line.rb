require_relative '../version'

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

      def run(args)
        params = {}

        ARGV << '-h' if ARGV.empty?
        OptionParser.new do |o|
          o.version = "v#{Dry::Stack::VERSION}"

          usage = [
            'dry-stack -s stackfile [options] COMMAND',
            'cat stackfile | dry-stack COMMAND',
            'dry-stack COMMAND < stack.drs'
          ]
          o.banner = "Usage:\n\t#{usage.join "\n\t"}"
          o.separator ''
          o.separator 'Commands:'
          COMMANDS.each { |name, cmd| o.separator "#{' ' * 5}#{name} -  #{cmd.help}" }

          o.separator ''
          o.separator 'Options:'

          #  in all caps are required
          o.on('-s', '--stack STACK_NAME', 'Stack file')
          o.on('-e', '--env', 'Load .env file') { load_env }
          o.on('-n', '--no-env', 'Do not process env variables') { true }
          o.on('-h', '--help') { puts o; exit }
          o.parse! args, into: params

          raise 'Stack file not defined' if $stdin.tty? && !params[:stack]

          command = args.shift || ''
          raise "Unknown command: #{command}" unless COMMANDS.key?(command.to_sym)

          eval $stdin.tty? ? File.read(params[:stack]) : STDIN.read
          COMMANDS[command.to_sym].run Stack.last_stack, params, args
        rescue => e
          puts e.message
          exit 1
        end
      end
    end
  end
end
