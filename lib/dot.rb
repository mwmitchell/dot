module Dot
  
  #
  #
  #
  class PathMatcher
    
    attr_accessor :path, :rules, :default_rule, :defaults
    
    def initialize(path, options={})
      self.path = clean_path(path).split('/')
      self.rules = options[:rules] || {}
      self.default_rule = /^\w+$/
      self.defaults = options[:defaults] || {}
    end
    
    def resolve(input_path)
      input_path = clean_path(input_path)
      return self.defaults if input_path == self.path.join('/')
      input = input_path.split('/')
      params=nil
      self.path.each_with_index do |v,i|
        next if v.to_s == input[i].to_s
        return unless v[0..0]==':'
        params||={}
        param_name=v[1..-1].to_sym
        if input[i].nil? and self.defaults[param_name]
          params[param_name] = self.defaults[param_name]
          next
        end
        if match?(param_name, input[i])
          params[param_name] = input[i]
          next
        end
        return
      end
      self.defaults.merge(params) unless params.nil?
    end
    
    def match?(param, value)
      value =~ (self.rules[param] || self.default_rule)
    end
    
    def clean_path(path)
      path.gsub(/\/+/, '/').sub(/^\/|\/$/, '')
    end
    
  end
  
  #
  #
  #
  module App
    
    class InvalidRequest < RuntimeError
      
    end
    
    def self.included(base)
      base.extend ClassMethods
    end
    
    module ClassMethods
    
      def mapping
        @mapping||=[]
      end
    
      def map(action, path='', options={})
        options[:rules]||={}
        mapping << {:path=>path, :action=>action, :options=>options}
      end
      
      def option(k,v)
        options||={}
        options[k]=v
      end
      
      def options
        @options||={
          :mutex=>true
        }
      end
      
    end
    
    [:request, :response, :action, :context_path, :route].each {|a| attr a}
    
    def options
      self.class.options
    end
    
    def call(env)
      exec!(Rack::Request.new(env), Rack::Response.new)
    end
    
    protected
    
    def find_matching_route
      m = self.class.mapping.sort {|a,b| b[:path].length <=> a[:path].length}
      m.each do |r|
        if params = Dot::PathMatcher.new(r[:path], r[:options]).resolve(@context_path)
          return [r, params]
        end
      end
      false
    end
    
    # sets the request, response routes etc.
    def prepare!(request, response, context_path=nil)
      @request = request
      @response = response
      @context_path = (context_path || @request.path_info).sub(/^\/+/, '').sub(/\/+$/, '')
      @action=nil
      @route, params = find_matching_route
      if @route
        @request.params.merge!(params) if params
        @action = @route[:action]
      end
    end
    
    # the main, root class execution point
    def exec!(request, response)
      prepare!(request, response)
      run_safely do
        handle_action_result(
          catch(:halt) do
            execute_action!
          end
        )
      end
      @response.finish
    end
    
    # attempts execution of the current @action
    def execute_action!
      if @action.nil? || ! respond_to?(@action)
        throw :halt, :status=>404, :body=>'Not Found'
      end
      begin
        catch :forward do |a, app|
          method(@action).call
        end
      rescue
        throw :halt, :status=>500, :body=>"Server Error: #{$!}"
      end
    end
    
    # allows an action in one class to pass the request to another
    # the fragments of the current @context_path are changed based on the current route depth
    def forward_to(klass)
      start = @route[:path].split('/').size
      handler = klass.new
      handler.prepare!(@request, @response, @context_path.split('/')[start..-1].join('/'))
      handler.execute_action!
    end
    
    # figures out what to do with a response from an action (or :halt) result
    def handle_action_result(result)
      @response.write result if result.is_a?(String)
      if result.is_a?(Hash)
        @response.write result[:body] if result[:body]
        @response.status = result[:status] if result[:status]
        @response.headers = result[:headers] if result[:headers]
      end
    end
    
    # Mutex instance used for thread synchronization.
    def mutex
      @@mutex ||= Mutex.new
    end

    # Yield to the block with thread synchronization
    def run_safely
      if options[:mutex]
        mutex.synchronize { yield }
      else
        yield
      end
    end
    
  end
  
end