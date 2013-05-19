net = require 'net'
http = require 'http'
coupler = require 'coupler'
Logger = require './logger'
Configuration = require './configuration'
portfinder = require 'portfinder'
{EventEmitter} = require 'events'

class Client extends EventEmitter
  constructor: ->
    @on 'listening', (server) -> Logger.info 'Listening on port ' + Logger.green(server.address().port)
    @on 'connected', => Logger.info 'Listening on ' + @domains.map((d) -> Logger.green(d)).join(', ')
    @on 'reconnected', -> Logger.info Logger.green('Reconnected') + ' to axle service'
    @on 'disconnected', -> Logger.info Logger.yellow('Lost Connection') + ' to axle service'
    
    @axle_service = coupler.connect(tcp: Configuration.service.port).consume('axle')
  
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
  
  start: ->
    createServer = http.createServer
    http.createServer = =>
      server_args = Array::slice.call(arguments)
      server = createServer.apply(http, server_args)
      return server if @intercepted
      @intercepted = true
      server.on 'error', => @on_server_error(server, server_args...)
      server.on 'listening', => @on_server_listening(server, server_args...)
      
      serverListen = server.listen
      server.listen = ->
        listen_args = Array::slice.call(arguments)
        callback = listen_args[listen_args.length - 1] if listen_args.length > 0 and typeof listen_args[listen_args.length - 1] is 'function'
        
        portfinder.getPort (err, port) =>
          if err?
            @emit('error', err)
            callback?(err)
            return
          serverListen.call(server, port, callback)
        
        server
      
      server
  
  stop: ->
    
  
module.exports = Client
