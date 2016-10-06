require 'yaml'
require 'json'

class OpenapiController < ApplicationController
  def show
    begin
      result = make_openapi_definition
    rescue Exception => e
      result = {'error' => YAML.dump(e)}
    end

    render status: :ok, json: result.to_json
  end

  def make_openapi_definition
    @openapi = {
      'swagger' => "2.0",
      'info' => {
        'title' => 'CCv3',
        'description' => 'OpenAPI Specification for a Cloud Foundry Cloud Controller V3 server.',
        'version' => "2.61.0",
        'contact' => {
          'name' => 'Cloud Foundry Foundation',
        },
        'license' => {
          'name' => 'Apache 2.0',
          'url' => 'http://www.apache.org/licenses/LICENSE-2.0.html',
        },
      },
      'basePath' => '/v3',
      'schemes' => ['http'],
      'paths' => {},
      'definitions' => {},
    }

    Rails.application.routes.routes.each do |route|
      @path = route.path.spec.to_s.
        sub(/\(\.:format\)$/, '').
        gsub(/:(\w+)/, '{\1}')
      break if @path == "/processes"  #XXX

      @method = route.constraints[:request_method].to_s.
        sub(/.*\^/, '').
        sub(/\$.*/, '').
        downcase
      @info = route.defaults
      @openapi['paths'][@path] ||= {}
      @definition = @openapi['paths'][@path][@method] = {}
      set_summary
      set_operation_id
      set_consumes
      set_produces
      set_parameters
      set_responses
    end

    return @openapi
  end
end

def set_summary
  @summary = @definition['summary'] = @info[:summary]
end

def set_operation_id
  @operation_id = @definition['operationId'] =
    @summary.
      gsub(/ (a|an|all|the) /, ' ').
      gsub(/ /, '_').
      camelize false
end

def set_consumes
  if @method != 'get'
    @definition['consumes'] = ['application/json']
  end
end

def set_produces
  @definition['produces'] = ['application/json']
end

def set_parameters
  description = {
    'guid' => 'Globally unique ID',
  }

  path = @path.split '/'
  path.shift
  path.each do |part|
    if m = part.match(/^\{(.*)\}$/)
      name = m[1]
      parameters = @definition['parameters'] ||= []
      parameters.push({
        'in' => 'path',
        'name' => name,
        'description' => description[name] || 'XXX',
        'required' => true,
        'type' => 'string',
      })
    end
  end
end

def set_responses
  description = {
    '200' => 'Successful',
  }

  if @method == 'get'
    status = '200'
  else
    return
  end
  @schema_ref = "#{@operation_id}Response"
  @definition['responses'] = {
    status => {
      'description' => description[status],
      'schema' => { '$ref' => "#/definitions/#{@schema_ref}" },
    }
  }

  add_definition
end

def add_definition
  @openapi['definitions'][@schema_ref] ||= {
    'properties' => {
      'xxx' => {
        'type' => 'string',
        'description' => 'XXX',
      }
    }
  }
end
