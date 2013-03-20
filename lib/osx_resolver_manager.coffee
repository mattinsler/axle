walkabout = require 'walkabout'
Logger = require './logger'
Configuration = require './configuration'

AXLE_RESOLVER = """
# Resolver for axle
nameserver 127.0.0.1
port #{Configuration.dns.port}
"""

class OsxResolverManager
  constructor: (@axle) ->
    @domains = {}
    @axle.routes.forEach (d) => @add_domain(d)
    
    @axle.on 'route:add', (route) =>
      @add_domain(route.host)
    
    @axle.on 'route:remove', (route) =>
      @remove_domain(route.host)
  
  add_domain: (domain) ->
    domain = domain.split('.').slice(-1)[0]
    return @domains[domain] if domain is '*'
    @domains[domain] ?= 0
    @create_resolver(domain) if @domains[domain] is 0
    ++@domains[domain]
  
  remove_domain: (domain) ->
    domain = domain.split('.').slice(-1)[0]
    return @domains[domain] if domain is '*'
    @domains[domain] ?= 0
    @remove_resolver(domain) if --@domains[domain] is 0
    @domains[domain]
  
  create_resolver: (domain) ->
    return unless @running is true
    
    Logger.info "write /etc/resolver/#{domain}"
    walkabout('/etc/resolver').mkdirp_sync()
    walkabout("/etc/resolver/#{domain}").write_file_sync(AXLE_RESOLVER)
  
  remove_resolver: (domain) ->
    return unless @running is true
    
    Logger.info "rm /etc/resolver/#{domain}"
    walkabout("/etc/resolver/#{domain}").unlink_sync() if walkabout("/etc/resolver/#{domain}").exists_sync()
  
  start: ->
    @running = true
  
  stop: ->
    @running = false

module.exports = OsxResolverManager
