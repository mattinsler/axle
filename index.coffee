exports.Axle = require './lib/axle'
exports.Client = require './lib/client'
exports.Service = require './lib/service'

exports.start_server = ->
  require 'colors'
  coupler = require 'coupler'
  
  log = -> console.log '[' + 'axle'.cyan + '] ' +  arguments[0]
  
  axle = new exports.Axle(process.env.PORT || 3000)
  coupler.accept(tcp: 1313).provide(axle: (connection) -> new exports.Service(axle, connection))
  
  axle.on 'listening', (address) -> log 'Listening on port ' + address.port.toString().green
  axle.on 'route:add', (route) -> log 'Added'.green + ' route ' + route.host + ' => ' + route.endpoint
  axle.on 'route:remove', (route) -> log 'Removed'.red + ' route ' + route.host + ' => ' + route.endpoint
  axle.on 'route:match', (from, to) -> log 'Routing ' + from.yellow + ' to ' + "#{to.host}:#{to.port}".green
  axle.on 'route:miss', (host) -> log 'No route for ' + host.red
  
  axle.start()
  axle
  
exports.start_client = ->
  require 'colors'
  coupler = require 'coupler'
  
  log = -> console.log '[' + 'axle'.cyan + '] ' +  arguments[0]
  
  if process.env.AXLE_DOMAINS?
    domains = process.env.AXLE_DOMAINS.split(',')
  else
    try
      pkg = require(process.cwd() + '/package')
      domains ?= pkg.axle_domains
      domains ?= "#{pkg.name}.localhost.dev"
      domains ?= []
      domains = [domains] unless Array.isArray(domains)
  
  axle_service = coupler.connect(tcp: 1313).consume('axle')
  client = new exports.Client(axle_service, domains)
  
  client.on 'listening', (server) -> log 'Listening on port ' + server.address().port.toString().green
  client.on 'connected', -> log 'Listening on ' + client.domains.map((d) -> d.green).join(', ')
  client.on 'reconnected', -> log 'Reconnected'.green + ' to axle service'
  client.on 'disconnected', -> log 'Lost Connection'.yellow + ' to axle service'
  
  client.start()
  client
