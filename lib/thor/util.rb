class Thor
  module Sandbox; end

  # This module holds several utilities:
  #
  # 1) Methods to convert thor namespaces to constants and vice-versa.
  #
  #   Thor::Utils.constant_to_namespace(Foo::Bar::Baz) #=> "foo:bar:baz"
  #   Thor::Utils.namespace_to_constant("foo:bar:baz") #=> Foo::Bar::Baz
  #
  # 2) Loading thor files and sandboxing:
  #
  #   Thor::Utils.load_thorfile("~/.thor/foo")
  #
  module Util

    # Receives a namespace and search for it in the Thor::Base subclasses.
    #
    # ==== Parameters
    # namespace<String>:: The namespace to search for.
    #
    def self.find_by_namespace(namespace)
      namespace = 'default' if namespace.empty?

      Thor::Base.subclasses.find do |klass|
        klass.namespace == namespace
      end
    end

    # Receives a constant and converts it to a Thor namespace. Since Thor tasks
    # can be added to a sandbox, this method is also responsable for removing
    # the sandbox namespace.
    #
    # ==== Parameters
    # constant<Object>:: The constant to be converted to the thor path.
    #
    # ==== Returns
    # String:: If we receive Foo::Bar::Baz it returns "foo:bar:baz"
    #
    def self.constant_to_namespace(constant, remove_default=true)
      constant = constant.to_s.gsub(/^Thor::Sandbox::/, "")
      constant = snake_case(constant).squeeze(":")
      constant.gsub!(/^default/, '') if remove_default
      constant
    end

    # Given the contents, evaluate it inside the sandbox and returns the thor
    # classes defined in the sandbox.
    #
    # ==== Parameters
    # contents<String>
    #
    # ==== Returns
    # Array[Object]
    #
    def self.namespaces_in_contents(contents, file=__FILE__)
      old_constants = Thor::Base.subclasses.dup
      Thor::Base.subclasses.clear

      load_thorfile(file, contents)

      new_constants = Thor::Base.subclasses.dup
      Thor::Base.subclasses.replace(old_constants)

      new_constants.map!{ |c| c.namespace }
      new_constants.compact!
      new_constants
    end

    # Receives a string and convert it to snake case. SnakeCase returns snake_case.
    #
    # ==== Parameters
    # String
    #
    # ==== Returns
    # String
    #
    def self.snake_case(str)
      return str.downcase if str =~ /^[A-Z_]+$/
      str.gsub(/\B[A-Z]/, '_\&').squeeze('_') =~ /_*(.*)/
      return $+.downcase
    end

    # Receives a namespace and tries to retrieve a Thor or Thor::Group class
    # from it. It first searches for a class using the all the given namespace,
    # if it's not found, removes the highest entry and searches for the class
    # again. If found, returns the highest entry as the class name.
    #
    # ==== Examples
    #
    #   class Foo::Bar < Thor
    #     def baz
    #     end
    #   end
    #
    #   class Baz::Foo < Thor::Group
    #   end
    #
    #   Thor::Util.namespace_to_thor_class("foo:bar")     #=> Foo::Bar, nil # will invoke default task
    #   Thor::Util.namespace_to_thor_class("baz:foo")     #=> Baz::Foo, nil
    #   Thor::Util.namespace_to_thor_class("foo:bar:baz") #=> Foo::Bar, "baz"
    #
    # ==== Parameters
    # namespace<String>
    #
    # ==== Errors
    # Thor::Error:: raised if the namespace cannot be found.
    #
    # Thor::Error:: raised if the namespace evals to a class which does not
    #               inherit from Thor or Thor::Group.
    #
    def self.namespace_to_thor_class(namespace)
      klass, task_name = Thor::Util.find_by_namespace(namespace), nil

      if klass.nil? && namespace.include?(?:)
        namespace = namespace.split(":")
        task_name = namespace.pop
        klass     = Thor::Util.find_by_namespace(namespace.join(":"))
      end

      raise Error, "could not find Thor class or task '#{namespace}'" unless klass

      return klass, task_name
    end

    # Receives a path and load the thor file in the path. The file is evaluated
    # inside the sandbox to avoid namespacing conflicts.
    #
    def self.load_thorfile(path, content=nil)
      content ||= File.read(path)

      begin
        Thor::Sandbox.class_eval(content, path)
      rescue Exception => e
        $stderr.puts "WARNING: unable to load thorfile #{path.inspect}: #{e.message}"
      end
    end

    # Prints a list. Used to show options and list of tasks.
    #
    # ==== Example
    #
    #   Thor::Util.print_list [["foo", "does some foo"], ["bar", "does some bar"]]
    #
    # Prints:
    #
    #    foo   # does some foo
    #    bar   # does some bar
    #
    # ==== Parameters
    # Array[Array[String, String]]
    #
    def self.print_list(list, options={})
      return if list.empty?

      list.map! do |item|
        item[0] = "  #{item[0]}" unless options[:skip_spacing]
        item[1] = item[1] ? "# #{item[1]}" : ""
        item
      end

      print_table(list)
    end

    # Prints a table. Right now it supports just a table with two columns.
    # Feel free to improve it if needed.
    #
    # ==== Parameters
    # Array[Array[String, String]]
    #
    def self.print_table(table)
      return if table.empty?

      maxima = table.max{ |a,b| a[0].size <=> b[0].size }[0].size
      format = "%-#{maxima+3}s"

      table.each do |first, second|
        print format % first
        print second
        puts
      end
    end

    # Receives a yaml (hash) and updates all constants entries to namespace.
    # This was added to deal with deprecated versions of Thor.
    #
    # ==== Returns
    # TrueClass|FalseClass:: Returns true if any change to the yaml file was made.
    #
    def self.convert_constants_to_namespaces(yaml)
      yaml_changed = false

      yaml.each do |k, v|
        next unless v[:constants] && v[:namespaces].nil?
        yaml_changed = true
        yaml[k][:namespaces] = v[:constants].map{|c| Thor::Util.constant_to_namespace(c)}
      end

      yaml_changed
    end

    # Returns the root where thor files are located, dependending on the OS.
    #
    def self.thor_root
      return File.join(ENV["HOME"], '.thor') if ENV["HOME"]

      if ENV["HOMEDRIVE"] && ENV["HOMEPATH"]
        return File.join(ENV["HOMEDRIVE"], ENV["HOMEPATH"], '.thor')
      end

      return File.join(ENV["APPDATA"], '.thor') if ENV["APPDATA"]

      begin
        File.expand_path("~")
      rescue
        if File::ALT_SEPARATOR
          "C:/"
        else
          "/"
        end
      end
    end

    # Returns the files in the thor root. On Windows thor_root will be something
    # like this:
    #
    #   C:\Documents and Settings\james\.thor
    #
    # If we don't #gsub the \ character, Dir.glob will fail.
    #
    def self.thor_root_glob
      files = Dir["#{thor_root.gsub(/\\/, '/')}/*"]

      files.map! do |file|
        File.directory?(file) ? File.join(file, "main.thor") : file
      end
    end

    # Where to look for Thor files.
    #
    def self.globs_for(path)
      ["#{path}/Thorfile", "#{path}/*.thor", "#{path}/tasks/*.thor", "#{path}/lib/tasks/*.thor"]
    end

  end
end
