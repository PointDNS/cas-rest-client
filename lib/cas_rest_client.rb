$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__))

require 'rubygems'
require 'rest_client'
require 'yaml'

module CasRestClient
end
require 'cas_rest_client/response'
require 'cas_rest_client/client'
