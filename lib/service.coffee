class Service
  constructor: (@axle, @socket) ->
    @domains = []
    
    @socket.on 'error', ->
      console.log 'ERROR'
      console.log arguments
    
    @socket.on 'close', =>
      @axle.remove(d) for d in @domains
    
    @socket.data(['register'], @register.bind(@))
  
  register: (domains) ->
    domains = [domains] unless Array.isArray(domains)
    Array::push.apply(@domains, domains)
    @axle.serve(d.host, d.endpoint) for d in domains
  
  routes: (callback) ->
    callback?(null, @axle.routes)

module.exports = Service
