# - axle registry
# - tcp service
# - dns server
# - proxy
# - web server for status

os = require 'os'
axle = require '../index'
walkabout = require 'walkabout'
exec = require('child_process').exec

Logger = axle.Logger

AXLE_RESOLVER = """
# Resolver for axle
nameserver 127.0.0.1
port #{axle.Configuration.dns.port}
"""

AXLE_PLIST_FILE = walkabout('/Library/LaunchAgents/com.mattinsler.axle.plist')
AXLE_DAEMON_PLIST = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>Label</key>
        <string>com.mattinsler.axle</string>
        <key>ProgramArguments</key>
        <array>
                <string>#{process.execPath}</string>
                <string>#{walkabout(__dirname).join('../bin/axle-server-run').absolute_path}</string>
        </array>
        <key>KeepAlive</key>
        <true/>
        <key>RunAtLoad</key>
        <true/>
        <key>Debug</key>
        <true/>
        <key>StandardOutPath</key>
        <string>/var/log/com.mattinsler.axle.log</string>
        <key>StandardErrorPath</key>
        <string>/var/log/com.mattinsler.axle.log</string>
</dict>
</plist>
"""

exports.install = ->
  Logger.info 'install'
  
  return Logger.error('Try running with sudo') unless process.getuid() is 0
  
  Logger.info 'mkdirp /etc/resolver'
  walkabout('/etc/resolver').mkdirp_sync()
  # Logger.info 'write /etc/resolver/axle'
  # walkabout('/etc/resolver/axle').write_file_sync(AXLE_RESOLVER)
  
  Logger.info 'write', AXLE_PLIST_FILE.absolute_path
  walkabout(AXLE_PLIST_FILE.dirname).mkdirp_sync()
  AXLE_PLIST_FILE.write_file_sync(AXLE_DAEMON_PLIST)
  
  Logger.info 'launch axle server'
  exec "launchctl unload #{AXLE_PLIST_FILE.absolute_path}", ->
    exec "launchctl load #{AXLE_PLIST_FILE.absolute_path}", ->
      Logger.info 'ok'

exports.uninstall = ->
  Logger.info 'uninstall'

  return Logger.error('Try running with sudo') unless process.getuid() is 0

  # Logger.info 'rm /etc/resolver/axle'
  # walkabout('/etc/resolver/axle').unlink_sync() if walkabout('/etc/resolver/axle').exists_sync()
  
  Logger.info 'stop axle server'
  exec "launchctl unload #{AXLE_PLIST_FILE.absolute_path}", ->
    Logger.info 'rm', AXLE_PLIST_FILE.absolute_path
    AXLE_PLIST_FILE.unlink_sync() if AXLE_PLIST_FILE.exists_sync()
    
    Logger.info 'ok'

exports.run_client = ->
  client = new axle.Client()
  
  if process.env.AXLE_DOMAINS?
    client.domains = process.env.AXLE_DOMAINS.split(',')
  else
    try
      pkg = require(process.cwd() + '/package')
      client.domains ?= pkg['axle-domains']
      client.domains ?= ["#{pkg.name}.localhost.dev"]
      client.domains ?= []
      client.domains = [domains] unless Array.isArray(domains)
  
  client.start()

exports.run_server = ->
  Logger.info 'server'
  
  return Logger.error('Try running with sudo') unless process.getuid() is 0
  
  instance = new axle.Axle()
  
  servers = []
  servers.push(new axle.Server(instance)) if instance.config.server.enabled
  servers.push(new axle.Service(instance)) if instance.config.service.enabled
  servers.push(new axle.Dns(instance)) if instance.config.dns.enabled
  
  servers.push(new axle.OsxResolverManager(instance)) if os.platform() is 'darwin'
  
  servers.forEach (s) -> s.start()
  
  process.on 'SIGTERM', ->
    servers.forEach (s) -> s.stop()
    Logger.info 'bye bye'
    process.exit(0)
  
  Logger.info 'started'

exports.daemon = ->
  
