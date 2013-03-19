http = require 'http'
distribute = require 'distribute'
Logger = require './logger'
{EventEmitter} = require 'events'

class Server extends EventEmitter
  constructor: (@axle) ->
    @on 'listening', (address) -> Logger.info 'Listening on port ' + Logger.green(address.port)
    @on 'forward', (from, to) -> Logger.info 'Forwarding ' + Logger.yellow(from) + ' to ' + Logger.green("#{to.host}:#{to.port}")
    
    @server = http.createServer()
    @server.on 'listening', => @emit('listening', @server.address())
    @server.on 'error', (err) => @emit('error', err)
    
    @distribute = distribute(@server)
    @distribute.use (req, res, next) =>
      try
        host = req.headers.host.split(':')[0]
        match = @axle.match(host)
        return next() unless match?
        @emit('forward', host, match)
        next(match.port, match.host)
      catch e
        next(e)
  
  start: ->
    @server.listen(@axle.config.server.port)

  stop: ->
    @server.close()

module.exports = Server
