module JettyRails
  module Handler
    class WebAppHandler < Jetty::Handler::WebAppContext
      attr_reader :config, :adapter
      
      def initialize(config)
        super("/", config[:context_path])
        @config = config

        self.class_loader = each_context_has_its_own_classloader
        self.resource_base = config[:base]
        self.descriptor = config[:web_xml]
        
        add_classes_dir_to_classpath(config)
        add_lib_dir_jars_to_classpath(config)
    
        @adapter = adapter_for(config[:adapter])
        self.init_params = @adapter.init_params
        
        @adapter.event_listeners.each do |listener|
          add_event_listener(listener)
        end

        add_filter(rack_filter, "/*", Jetty::Context::DEFAULT)
      end
  
      def self.add_adapter(adapter_key, adapter)
        adapters[adapter_key] = adapter
      end
  
      def self.adapters
        @adapters ||= {
          :rails => JettyRails::Adapters::RailsAdapter,
          :merb => JettyRails::Adapters::MerbAdapter
        }
      end
      
      def adapters
        self.class.adapters
      end
  
      protected
      def rack_filter
        Jetty::FilterHolder.new(Rack::RackFilter.new)
      end
  
      def adapter_for(kind)
        adapters[kind.to_sym].new(@config)
      end
      
      private
      def add_lib_dir_jars_to_classpath(config)
        lib_dir = "#{config[:base]}/#{config[:lib_dir]}/**/*.jar"
        Dir[lib_dir].each do |jar|
          url = java.io.File.new(jar).to_url
          self.class_loader.add_url(url)
        end
      end
      def add_classes_dir_to_classpath(config)
        classes_dir = "#{config[:base]}/#{config[:classes_dir]}"
        url = java.io.File.new(classes_dir).to_url
        self.class_loader.add_url(url)
      end
      def each_context_has_its_own_classloader()
        org.jruby.util.JRubyClassLoader.new(JRuby.runtime.jruby_class_loader)
      end
    end
  end
end
