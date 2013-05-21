net = require 'net'
http = require 'http'
portfinder = require 'portfinder'
EventEmitter = require('events').EventEmitter

class Client extends EventEmitter
  constructor: (@socket, @domains) ->
    @socket.on 'error', ->
      # eat it
    @socket.on 'start', =>
      @is_connected = true
    @is_connected = @socket.connected
  
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
    
    emit_connected = =>
      return @emit('reconnected', server) if @was_previously_connected
      @was_previously_connected = true
      @emit('connected', server)
    
    if @socket.connected
      @socket.send(['register'], @domains.map (d) -> {host: d, endpoint: server.address().port})
      emit_connected()
    
    @socket.on 'start', =>
      @socket.send(['register'], @domains.map (d) -> {host: d, endpoint: server.address().port})
      emit_connected()
    
    @socket.on 'close', =>
      @emit('disconnected', server) if @is_connected
      @is_connected = false

module.exports = Client
