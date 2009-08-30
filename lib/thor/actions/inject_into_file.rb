require 'thor/actions/empty_directory'

class Thor
  module Actions

    # Injects the given content into a file. Different from append_file,
    # prepend_file and gsub_file, this method is reversible. By this reason,
    # the flag can only be strings. gsub_file is your friend if you need to
    # deal with more complex cases.
    #
    # ==== Parameters
    # destination<String>:: Relative path to the destination root
    # data<String>:: Data to add to the file. Can be given as a block.
    # config<Hash>:: give :verbose => false to not log the status and the flag
    #                for injection (:after or :before).
    # 
    # ==== Examples
    #
    #   inject_into_file "config/environment.rb", "config.gem :thor", :after => "Rails::Initializer.run do |config|\n"
    #
    #   inject_into_file "config/environment.rb", :after => "Rails::Initializer.run do |config|\n" do
    #     gems = ask "Which gems would you like to add?"
    #     gems.split(" ").map{ |gem| "  config.gem :#{gem}" }.join("\n")
    #   end
    #
    def inject_into_file(destination, *args, &block)
      if block_given?
        data, config = block, args.shift
      else
        data, config = args.shift, args.shift
      end

      log_status = args.empty? || args.pop
      action InjectIntoFile.new(self, destination, data, config)
    end

    class InjectIntoFile < EmptyDirectory #:nodoc:
      attr_reader :replacement

      def initialize(base, destination, data, config)
        super(base, destination, { :verbose => true }.merge(config))
        @replacement = data.is_a?(Proc) ? data.call : data
      end

      def invoke!
        say_status :inject, config[:verbose]

        flag = if @config.key?(:after)
          content = '\0' + replacement
          @config[:after]
        else
          content = replacement + '\0'
          @config[:before]
        end

        replace!(flag, content)
      end

      def revoke!
        say_status :deinject, config[:verbose]

        flag = if @config.key?(:after)
          content = '\1\2'
          /(#{Regexp.escape(@config[:after])})(.*)(#{Regexp.escape(replacement)})/m
        else
          content = '\2\3'
          /(#{Regexp.escape(replacement)})(.*)(#{Regexp.escape(@config[:before])})/m
        end

        replace!(flag, content)
      end

      protected

        # Adds the content to the file.
        #
        def replace!(regexp, string)
          unless base.options[:pretend]
            content = File.read(destination)
            content.gsub!(regexp, string)
            File.open(destination, 'wb') { |file| file.write(content) }
          end
        end

    end
  end
end
