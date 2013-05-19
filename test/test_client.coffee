http = require 'http'

server = require('http').createServer (req, res) ->
  console.log 'REQUEST'
  res.writeHead(200, 'Content-Type': 'text/plain')
  res.end('Hello World')
.listen(process.env.PORT || 3000)
