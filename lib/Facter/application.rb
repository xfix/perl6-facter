module Facter
  module Application
    def self.run(argv)
      require 'optparse'
      require 'facter'

      options = parse(argv)

      # Accept fact names to return from the command line
      names = argv

      # Create the facts hash that is printed to standard out
      if names.empty?
        facts = Facter.to_hash
      else
        facts = {}
        names.each { |name|
          begin
            facts[name] = Facter.value(name)
          rescue => error
            $stderr.puts "Could not retrieve #{name}: #{error}"
            exit 10
          end
        }
      end

      # Print the facts as YAML and exit
      if options[:yaml]
        require 'yaml'
        puts YAML.dump(facts)
        exit(0)
      end

      # Print the facts as JSON and exit
      if options[:json]
        begin
          require 'json'
          puts JSON.dump(facts)
          exit(0)
        rescue LoadError
          $stderr.puts "You do not have JSON support in your version of Ruby. JSON output disabled"
          exit(1)
        end
      end

      # Print the value of a single fact, otherwise print a list sorted by fact
      # name and separated by "=>"
      if facts.length == 1
        if value = facts.values.first
          puts value
        end
      else
        facts.sort_by{ |fact| fact.first }.each do |name,value|
          puts "#{name} => #{value}"
        end
      end

    rescue => e
      if options && options[:trace]
        raise e
      else
        $stderr.puts "Error: #{e}"
        exit(12)
      end
    end

    private

    def self.parse(argv)
      options = {}
      OptionParser.new do |opts|
        opts.on("-y", "--yaml")   { |v| options[:yaml]   = v }
        opts.on("-j", "--json")   { |v| options[:json]   = v }
        opts.on(      "--trace")  { |v| options[:trace]  = v }
        opts.on("-d", "--debug")  { |v| Facter.debugging(1) }
        opts.on("-t", "--timing") { |v| Facter.timing(1) }
        opts.on("-p", "--puppet") { |v| load_puppet }

        opts.on_tail("-v", "--version") do
          puts Facter.version
          exit(0)
        end

        opts.on_tail("-h", "--help") do
          begin
            require 'rdoc/ri/ri_paths'
            require 'rdoc/usage'
            puts RDoc.usage
          rescue LoadError
            $stderr.puts "No help available unless your RDoc has RDoc.usage"
            exit(1)
          rescue => e
            $stderr.puts "fatal: #{e}"
            exit(1)
          end
        end
      end.parse!

      options
    rescue OptionParser::InvalidOption => e
      $stderr.puts e.message
      exit(12)
    end

    def self.load_puppet
      require 'puppet'
      Puppet.parse_config

      # If you've set 'vardir' but not 'libdir' in your
      # puppet.conf, then the hook to add libdir to $:
      # won't get triggered.  This makes sure that it's setup
      # correctly.
      unless $LOAD_PATH.include?(Puppet[:libdir])
        $LOAD_PATH << Puppet[:libdir]
      end
    rescue LoadError => detail
      $stderr.puts "Could not load Puppet: #{detail}"
    end

  end
end
