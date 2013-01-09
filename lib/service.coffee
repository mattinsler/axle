class Service
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

module.exports = Service
