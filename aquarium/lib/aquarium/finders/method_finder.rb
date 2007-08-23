require 'set'
require File.dirname(__FILE__) + '/../utils/array_utils'
require File.dirname(__FILE__) + '/../utils/invalid_options'
require File.dirname(__FILE__) + '/finder_result'

# Find methods and types and objects.
module Aquarium
  module Finders
    class MethodFinder
      include Aquarium::Utils::ArrayUtils
  
      # Returns a Aquarium::Finders::FinderResult for the hash of types, type names, and/or regular expressions
      # and the corresponding method name <b>symbols</b> found.
      # Method names, not method objects, are always returned, because we can only get
      # method objects for instance methods if we have an instance!
      #
      # finder_result = MethodFinder.new.find :types => ... {, :methods => ..., :options => [...]}
      # where
      # "{}" indicate optional arguments
      #
      # <tt>:types => types_and_type_names_and_regexps</tt>::
      # <tt>:type  => types_and_type_names_and_regexps</tt>::
      #   One or more types, type names and/or regular expessions to match. 
      #   Specify one or an array of values.
      #
      # <tt>:objects => objects</tt>::
      # <tt>:object  => objects</tt>::
      #   One or more objects to match. 
      #   Specify one or an array of values.
      #   Note: Currently, string or symbol objects will be misinterpreted as type names!
      #
      # <tt>:methods => method_names_and_regexps</tt>::
      # <tt>:method  => method_names_and_regexps</tt>::
      #   One or more method names and regular expressions to match.
      #   Specify one or an array of values.
      #
      # <tt>:options => method_options</tt>::
      #   By default, searches for public instance methods. Specify one or more
      #   of the following options for alternatives. You can combine any of the
      #   <tt>:public</tt>, <tt>:protected</tt>, and <tt>:private</tt>, as well as
      #   <tt>:instance</tt> and <tt>:class</tt>.
      #     
      # <tt>:public</tt>::    Search for public methods (default).
      # <tt>:private</tt>::   Search for private methods. 
      # <tt>:protected</tt>:: Search for protected methods.
      # <tt>:instance</tt>::  Search for instance methods.
      # <tt>:class</tt>::     Search for class methods.
      # <tt>:singleton</tt>:: Search for singleton methods. (Using :class for objects 
      # won't work and :class, :public, :protected, and :private are ignored when 
      # looking for singleton methods.)
      # <tt>:suppress_ancestor_methods</tt>:: Suppress "ancestor" methods. This
      # means that if you search for a override method +foo+ in a
      # +Derived+ class that is defined in the +Base+ class, you won't find it!
      #
      def find options = {}
        init_specification options
        types_and_objects = input_types + input_objects
        return Aquarium::Finders::FinderResult.new if types_and_objects.empty? 
        method_names_or_regexps = input_methods
        if method_names_or_regexps.empty?
          not_matched = {}
          types_and_objects.each {|t| not_matched[t] = []}
          return Aquarium::Finders::FinderResult.new(:not_matched => not_matched)
        end
        method_options = make_array options[:options]
        find_all_by types_and_objects, method_names_or_regexps, method_options
      end
  
      # finder_result = MethodFinder.new.find_all_by types_and_objects, [methods, [options]]
      # where if no +methods+ are specified, all are returned, subject to the +options+,
      # as in #find.
      def find_all_by types_and_objects, method_names_or_regexps = :all, *scope_options
        return Aquarium::Finders::FinderResult.new if types_and_objects.nil? 
        @specification = make_options_hash scope_options
        types_and_objects = make_array types_and_objects
        names_or_regexps  = make_methods_array method_names_or_regexps
        types_and_objects_to_matched_methods = {}
        types_and_objects_not_matched = {}
        types_and_objects.each do |type_or_object|
          reflection_method_names = make_methods_reflection_method_names type_or_object, "methods"
          found_methods = Set.new
          names_or_regexps.each do |name_or_regexp|
            method_array = []
            reflection_method_names.each do |reflect|
              method_array += reflect_methods(type_or_object, reflect).grep(make_regexp(name_or_regexp))
            end
            if @specification[:suppress_ancestor_methods]
              method_array = remove_ancestor_methods type_or_object, reflection_method_names, method_array
            end
            found_methods += method_array
          end
          if found_methods.empty?
            types_and_objects_not_matched[type_or_object] = method_names_or_regexps
          else
            types_and_objects_to_matched_methods[type_or_object] = found_methods.to_a.sort.map {|m| m.intern}
          end
        end
        Aquarium::Finders::FinderResult.new types_and_objects_to_matched_methods.merge(:not_matched => types_and_objects_not_matched)
      end
  
      NIL_OBJECT = MethodFinder.new unless const_defined?(:NIL_OBJECT)
  
      def self.is_recognized_method_option string_or_symbol
        %w[public private protected 
           instance class suppress_ancestor_methods].include? string_or_symbol.to_s 
      end
  
      protected
  
      def init_specification options
        options[:options] = make_array(options[:options]) unless options[:options].nil?
        validate options
        @specification = options
      end
      
      def input_types
        make_array @specification[:types], @specification[:type]
      end
  
      def input_objects
        make_array @specification[:objects], @specification[:object]
      end
  
      def input_methods
        make_array @specification[:methods], @specification[:method]
      end
  
      private
  
      def make_methods_array *array_or_single_item
        ary = make_array(*array_or_single_item).reject {|m| m.to_s.strip.empty?}
        ary = [/^.+$/] if ary.include?(:all) 
        ary
      end
  
      def make_regexp name_or_regexp
        name_or_regexp.kind_of?(Regexp) ? name_or_regexp : /^#{Regexp.escape(name_or_regexp.to_s)}$/
      end
  
      def remove_ancestor_methods type_or_object, reflection_method_names, method_array
        type = type_or_object
        unless (type_or_object.instance_of?(Class) or type_or_object.instance_of?(Module)) 
          type = type_or_object.class
          # Must recalc reflect methods if we've switched to the type of the input object.
          reflection_method_names = make_methods_reflection_method_names type, "methods"
        end
        ancestors = eval "#{type.to_s}.ancestors + #{type.to_s}.included_modules"
        return method_array if ancestors.nil? || ancestors.size <= 1 # 1 for type_or_object itself!
        ancestors.each do |ancestor|
          unless ancestor.name == type.to_s
            reflection_method_names.each do |reflect|
              method_array -= ancestor.method(reflect).call
            end
          end
        end
        method_array
      end
  
      def make_options_hash *scope_options
        return {} if scope_options.nil?
        options = {}
        scope_options.flatten.each {|o| options[o] = '' unless o.nil?}
        unless options[:class] || options[:instance] || options[:singleton]
          options[:instance] = ''
        end
        options
      end
  
      def make_methods_reflection_method_names type_or_object, root_method_name
        is_type = type_or_object.instance_of?(Class) || type_or_object.instance_of?(Module)
        scope_prefixes = []
        class_instance_prefixes = []
        @specification.each do |opt, value|
          opt_string = opt.to_s
          case opt_string
          when "public", "private", "protected" 
            scope_prefixes += [opt_string + "_"]
          when "instance"
            class_instance_prefixes += is_type ? [opt_string + "_"] : [""]
          when "class"
            # We want to use the "bare" (public_|private_|)<root_method_name> calls 
            # to get class methods, because we will invoke these methods on class objects!
            # For instances, class methods aren't supported.
            class_instance_prefixes += [""] if is_type
          when "singleton"
            class_instance_prefixes += [opt_string + "_"]
          else 
            true # do nothing; "true" is here to make rcov happy.
          end
        end
        scope_prefixes = ["public_"] if scope_prefixes.empty?
        class_instance_prefixes = [""] if (class_instance_prefixes.empty? and is_type)
        results = []
        scope_prefixes.each do |scope_prefix|
          class_instance_prefixes.each do |class_instance_prefix|
            prefix  = class_instance_prefix.eql?("singleton_") ? class_instance_prefix : scope_prefix + class_instance_prefix
            results += [(prefix + root_method_name).intern]
          end
        end
        results
      end
  
      def reflect_methods type_or_object, reflect_method
        if type_or_object.kind_of?(String) or type_or_object.kind_of?(Symbol)
          eval "#{type_or_object.to_s}.#{reflect_method}"
        else
          return [] unless type_or_object.respond_to? reflect_method
          m = type_or_object.method reflect_method
          m.call type_or_object
        end
      end
  
      def validate options
        allowed = %w[type types object objects method methods options class instance public private protected suppress_ancestor_methods].map {|x| x.intern}
        okay, bad = options.keys.partition {|x| allowed.include?(x)}
        raise Aquarium::Utils::InvalidOptions.new("Unrecognized option(s): #{bad.inspect}") unless bad.empty?
        method_options = options[:options]
        return if method_options.nil?
        if method_options.include?(:singleton) && 
          (method_options.include?(:class) || method_options.include?(:public) ||
           method_options.include?(:protected) || method_options.include?(:private))
          raise Aquarium::Utils::InvalidOptions.new("The :class:, :public, :protected, and :private flags can't be used with the :singleton flag.")
        end
      end
    end
  end
end
