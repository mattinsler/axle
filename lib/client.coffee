net = require 'net'
http = require 'http'
portfinder = require 'portfinder'
EventEmitter = require('events').EventEmitter

class Client extends EventEmitter
  constructor: (@socket, @domains) ->
    @is_connected = @socket.connected
    @was_previously_connected = false
    
    @socket.on 'error', -> # eat it
    @socket.on 'start', => @is_connected = true
    @socket.on 'close', => @is_connected = false
    
    @socket.data ['axle', 'register', 'ack'], (data) =>
      return @emit('reconnected', @server) if @was_previously_connected is true
      @was_previously_connected = true
      @emit('connected', @server)
  
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
  
  register: ->
    domain_data = @domains.map (d) => {host: d, endpoint: @server.address().port}
    @socket.send(['axle', 'register'], domains: domain_data)
  
  on_server_listening: (server) ->
    @server = server
    @emit('listening', @server)
    
    @register() if @is_connected
    
    @socket.on 'start', => @register()
    @socket.on 'close', =>
      @emit('disconnected', @server) if @is_connected

module.exports = Client
