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
    @files_created = {}
    process.on 'exit', =>
      walkabout(f).unlink_sync() for f, x of @files_created
    
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
    
    file = walkabout("/etc/resolver/#{domain}")
    
    Logger.info "write #{file.absolute_path}"
    unless file.exists_sync()
      file.directory().mkdirp_sync()
      file.write_file_sync(AXLE_RESOLVER)
      @files_created[file.absolute_path] = 1
    @
  
  remove_resolver: (domain) ->
    return unless @running is true
    
    file = walkabout("/etc/resolver/#{domain}")
    
    Logger.info "rm #{file.absolute_path}"
    file.unlink_sync() if file.exists_sync()
    delete @files_created[file.absolute_path]
  
  start: ->
    @running = true
  
  stop: ->
    @running = false

module.exports = OsxResolverManager
