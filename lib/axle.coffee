{EventEmitter} = require 'events'
Logger = require './logger'

parse_endpoint = (endpoint) ->
  if parseInt(endpoint).toString() is endpoint.toString()
    target_host = 'localhost'
    target_port = parseInt(endpoint)
  else
    [target_host, target_port] = endpoint.split(':')
    target_port = if target_port? then parseInt(target_port) else 80
  
  {host: target_host, port: target_port}

class RoutePredicate
  constructor: (@host, @endpoint) ->
    @target = parse_endpoint(@endpoint)
  
  matches: (host) ->
    @host is host

class WildcardRoutePredicate extends RoutePredicate
  constructor: ->
    super
    @rx = new RegExp('^' + @host.replace(/\./g, '\\.').replace(/\*/g, '.*') + '$')
    
  matches: (host) ->
    @rx.test(host)

class Axle extends EventEmitter
  config: require './configuration'
  
  constructor: ->
    @routes = []
    
    @on 'route:add', (route) -> Logger.info Logger.green('Added') + ' route ' + route.host + ' => ' + route.endpoint
    @on 'route:remove', (route) -> Logger.info Logger.red('Removed') + ' route ' + route.host + ' => ' + route.endpoint
    @on 'route:match', (from, to) -> Logger.debug 'Matched route for ' + Logger.yellow(from) + ' to ' + Logger.green("#{to.host}:#{to.port}")
    @on 'route:miss', (host) -> Logger.debug 'No route for ' + Logger.red(host)
  
  remove: (route) ->
    @routes = @routes.filter (r) =>
      if r.host is route.host and r.endpoint is route.endpoint
        @emit('route:remove', r)
        return false
      true

  serve: (host, endpoint) ->
    if host.indexOf('*') isnt -1
      @routes.push(new WildcardRoutePredicate(host, endpoint))
    else
      @routes.push(new RoutePredicate(host, endpoint))
    @emit('route:add', {host: host, endpoint: endpoint})
  
  match: (host) ->
    for e in @routes
      if e.matches(host)
        @emit('route:match', host, e.target)
        return e.target
    
    @emit('route:miss', host)
    null

module.exports = Axle
