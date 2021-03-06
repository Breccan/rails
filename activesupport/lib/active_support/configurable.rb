require 'active_support/concern'
require 'active_support/ordered_options'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  # Configurable provides a <tt>config</tt> method to store and retrieve
  # configuration options as an <tt>OrderedHash</tt>.
  module Configurable
    extend ActiveSupport::Concern

    class Configuration < ActiveSupport::InheritableOptions
      def compile_methods!
        self.class.compile_methods!(keys.reject {|key| respond_to?(key)})
      end

      # compiles reader methods so we don't have to go through method_missing
      def self.compile_methods!(keys)
        keys.each do |key|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{key}; _get(#{key.inspect}); end
          RUBY
        end
      end
    end

    module ClassMethods
      def config
        @_config ||= if respond_to?(:superclass) && superclass.respond_to?(:config)
          superclass.config.inheritable_copy
        else
          # create a new "anonymous" class that will host the compiled reader methods
          Class.new(Configuration).new
        end
      end

      def configure
        yield config
      end

      # Allows you to add shortcut so that you don't have to refer to attribute through config.
      # Also look at the example for config to contrast.
      #
      #   class User
      #     include ActiveSupport::Configurable
      #     config_accessor :allowed_access
      #   end
      #
      #   user = User.new
      #   user.allowed_access = true
      #   user.allowed_access # => true
      #
      def config_accessor(*names)
        names.each do |name|
          code, line = <<-RUBY, __LINE__ + 1
            def #{name}; config.#{name}; end
            def #{name}=(value); config.#{name} = value; end
          RUBY

          singleton_class.class_eval code, __FILE__, line
          class_eval code, __FILE__, line
        end
      end
    end

    # Reads and writes attributes from a configuration <tt>OrderedHash</tt>.
    #
    #   require 'active_support/configurable'
    #
    #   class User
    #     include ActiveSupport::Configurable
    #   end
    #
    #   user = User.new
    #
    #   user.config.allowed_access = true
    #   user.config.level = 1
    #
    #   user.config.allowed_access # => true
    #   user.config.level          # => 1
    #
    def config
      @_config ||= self.class.config.inheritable_copy
    end
  end
end

