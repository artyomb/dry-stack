
module Dry
  module CommandLine
    COMMANDS = {}

    class << self
      def run(args)
        stack_file = false
        stack_file = STDIN.read unless $stdin.tty?

        ARGV << '-h' if ARGV.empty?
        OptionParser.new do |o|
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
          o.on('-s', '--stack STACK_NAME', 'Stack file') { |v| stack_file = v }
          o.on('-h', '--help') { puts o; exit }
          o.parse! args

          raise 'Stack file not defined' unless stack_file

          command = args.shift
          raise "Unknown command: #{command}" unless COMMANDS.key?(command.to_sym)

          eval $stdin.tty? ? File.read(stack_file) : stack_file
          COMMANDS[command.to_sym].run Stack.last_stack, args
        rescue => e
          puts e.message
          exit 1
        end
      end
    end
  end
end
