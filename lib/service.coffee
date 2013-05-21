class Service
  constructor: (@axle, @socket) ->
    @domains = []
    
    @socket.on 'error', -> # eat it
    @socket.on 'close', =>
      @axle.remove(d) for d in @domains
    
    @socket.data ['axle', 'register'], (data) =>
      @register(data.domains)
      @socket.send(['axle', 'register', 'ack'], data)
  
  register: (domains) ->
    domains = [domains] unless Array.isArray(domains)
    Array::push.apply(@domains, domains)
    @axle.serve(d.host, d.endpoint) for d in domains
  
  routes: (callback) ->
    callback?(null, @axle.routes)

module.exports = Service
