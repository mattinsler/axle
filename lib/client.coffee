net = require 'net'
http = require 'http'
portfinder = require 'portfinder'
EventEmitter = require('events').EventEmitter

class Client extends EventEmitter
  constructor: (@axle_service, @domains) ->
  
  start: ->
    createServer = http.createServer
    http.createServer = =>
      server = createServer.apply(http, arguments)
      return server if @intercepted
      @intercepted = true
      server.on 'error', => @on_server_error(server, arguments...)
      server.on 'listening', => @on_server_listening(server, arguments...)
      server
  
  on_server_error: (server, err) ->
    if err.code is 'EADDRINUSE'
      portfinder.getPort (e, port) =>
        return @emit('error', e) if e?
        server.listen(port)
  
  on_server_listening: (server) ->
    @emit('listening', server)
    
    @axle_service.on 'coupler:connected', =>
      @axle_service.register(@domains.map (d) -> {host: d, endpoint: server.address().port})
      @emit('connected', server)
    
    @axle_service.on 'coupler:reconnected', =>
      @emit('reconnected', server)
    
    @axle_service.on 'coupler:disconnected', =>
      @emit('disconnected', server)
  
module.exports = Client
