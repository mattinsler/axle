coupler = require 'coupler'

class Client
  constructor: (@axle, @connection) ->
    @connection.on 'coupler:connected', =>
      @domains = []
    @connection.on 'coupler:disconnected', =>
      @axle.remove(d) for d in @domains
  
  register: (domains) ->
    domains = [domains] unless Array.isArray(domains)
    Array::push.apply(@domains, domains)
    @axle.serve(d.host, d.endpoint) for d in domains
  
  routes: (callback) ->
    callback?(null, @axle.routes)


class Service
  constructor: (@axle) ->
  
  start: ->
    @service = coupler
      .accept(tcp: @axle.config.service.port)
      .provide(
        axle: (connection) =>
          new Client(@axle, connection)
      )
  
  stop: ->
    

module.exports = Service
