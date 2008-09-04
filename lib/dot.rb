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
    
      def map(path, action, options={})
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
    
    [:request, :response, :action, :path_info].each {|a| attr a}
    
    def options
      self.class.options
    end
    
    def call(env)
      @request = Rack::Request.new(env)
      @path_info = @request.path_info.sub(/^\/+/, '').sub(/\/+$/, '')
      @response = Rack::Response.new
      @response.headers['Content-Type'] = 'text/plain'
      @response.status==200
      @action=nil
      m = self.class.mapping.sort {|a,b| b[:path].length <=> a[:path].length}
      m.each do |r|
        pm = Dot::PathMatcher.new(r[:path], r[:options])
        if params = pm.resolve(@path_info)
          @request.params.merge!(params)
          @action=r[:action]
          break
        end
      end
      
      run_safely do
        handle_result(
          catch(:halt) do
            if @action.nil? || ! respond_to?(@action)
              throw :halt, :status=>404, :body=>'Not Found'
            end
            begin
              method(@action).call
            rescue
              throw :halt, :status=>500, :body=>"Server Error: #{$!}"
            end
          end
        )
      end
      @response.finish
    end
    
    protected
    
    #
    def handle_result(result)
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