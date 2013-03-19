dgram = require 'dgram'
packed = require 'packed'
walkabout = require 'walkabout'
DnsServer = require('dnsserver').Server

REQUEST_TYPES =
  A: 1
  AAAA: 28
  CNAME: 5
  MX: 15
  NS: 2
REQUEST_TYPES[v] = k for k, v of REQUEST_TYPES

domain_string = {
  unpack: (buffer) ->
    o = @byte_offset
    str = (while (len = buffer.readUInt8(o)) isnt 0
      buffer.slice(o + 1, o += 1 + len).toString('ascii')
    ).join('.')
    [str, o + 1]
  pack: (buffer, value) ->
    o = @byte_offset
    for v in value.split('.')
      buffer.writeUInt8(v.length, o++)
      new Buffer(v, 'ascii').copy(buffer, o)
      o += v.length
    buffer.writeUInt8(0, o)
    [o + 1]
}

ip_address = {
  unpack: (buffer) ->
    ['', @byte_offset + 4]
  pack: (buffer, value) ->
    i = value.split('.')
    buffer.writeUInt8(parseInt(i[0]), @byte_offset)
    buffer.writeUInt8(parseInt(i[1]), @byte_offset + 1)
    buffer.writeUInt8(parseInt(i[2]), @byte_offset + 2)
    buffer.writeUInt8(parseInt(i[3]), @byte_offset + 3)
    [@byte_offset + 4]
}

DnsRequest = packed
  header:
    qid: packed.uint16
    flags:
      qr: packed.bits(1)
      opcode: packed.bits(4)
      aa: packed.bits(1)
      tc: packed.bits(1)
      rd: packed.bits(1)
      ra: packed.bits(1)
      z: packed.bits(3)
      rcode: packed.bits(4)
    qcount: packed.uint16
    acount: packed.uint16
    auth_count: packed.uint16
    addl_count: packed.uint16
  question:
    domain: domain_string
    qtype: packed.uint16
    qclass: packed.uint16

DnsResponse = packed
  header:
    qid: packed.uint16
    flags:
      qr: packed.bits(1)
      opcode: packed.bits(4)
      aa: packed.bits(1)
      tc: packed.bits(1)
      rd: packed.bits(1)
      ra: packed.bits(1)
      z: packed.bits(3)
      rcode: packed.bits(4)
    qcount: packed.uint16
    acount: packed.uint16
    auth_count: packed.uint16
    addl_count: packed.uint16
  question:
    domain: domain_string
    qtype: packed.uint16
    qclass: packed.uint16
  answer:
    name: packed.uint16
    qtype: packed.uint16
    qclass: packed.uint16
    ttl: packed.uint32
    data_length: packed.uint16
    data: ip_address

class Dns
  constructor: (@axle) ->
    @read_nameservers()
    
    @server = dgram.createSocket('udp4')
    @server.on('message', @on_message.bind(@))
  
  read_nameservers: ->
    @nameservers = walkabout('/etc/resolv.conf').read_file_sync()
      .split('\n')
      .filter((line) -> line[0] isnt '#')
      .map((line) -> /nameserver[ \t]+(.+)\b/.exec(line))
      .filter((match) -> match?)
      .map((match) -> match[1])
      .filter((ip) -> ip not in ['0.0.0.0', '127.0.0.1', 'localhost'])
  
  parse: (msg) ->
    DnsRequest.unpack(msg)
    
    # read_string = (offset) ->
    #   length = msg.readUInt8(offset)
    #   msg.slice(offset + 1, offset + 1 + length).toString('ascii')
    # 
    # parsed = {}
    # 
    # parsed.qid = msg.readUInt16BE(0)
    # parsed.flags = msg.readUInt16BE(2)
    # parsed.qcount = msg.readUInt16BE(4)
    # parsed.acount = msg.readUInt16BE(6)
    # parsed.auth_count = msg.readUInt16BE(8)
    # parsed.addl_count = msg.readUInt16BE(10)
    # 
    # offset = 12
    # 
    # parsed.domain = []
    # while msg.readUInt8(offset) isnt 0
    #   d = read_string(offset)
    #   parsed.domain.push(d)
    #   offset += 1 + d.length
    # 
    # ++offset
    # 
    # parsed.domain = parsed.domain.join('.')
    # 
    # parsed.qtype = msg.readUInt16BE(offset)
    # parsed.qclass = msg.readUInt16BE(offset + 2)
    # parsed.qtype_readable = REQUEST_TYPES[parsed.qtype] ? 'UNKNOWN'
    # 
    # parsed
  
  adjust_response_ttl: (response, ttl) ->
    questions = response.readUInt16BE(4)
    answers = response.readUInt16BE(6)
    
    answer_offset = question_offset = 12
    for x in [0...questions]
      ++answer_offset while response.readUInt8(answer_offset) isnt 0
      answer_offset += 5
    
    for x in [0...answers]
      ttl_offset = answer_offset + 6
      
      old_ttl = response.readUInt32BE(ttl_offset)
      response.writeUInt32BE(ttl, ttl_offset)
      
      ip_length_offset = ttl_offset + 4
      ip_length = response.readUInt16BE(ip_length_offset)
      answer_offset = ip_length_offset + 2 + ip_length
    
    response
  
  forward_dns: (remote_info, msg) ->
    client = dgram.createSocket('udp4')
    
    client.on 'message', (data, rinfo) =>
      client.close()
      @server.send(@adjust_response_ttl(data, 1), 0, data.length, remote_info.port, remote_info.address)
    
    client.send(msg, 0, msg.length, 53, @nameservers[0])
  
  respond_with: (ip_address, remote_info, req) ->
    res = DnsResponse.pack(
      header:
        qid: req.header.qid
        flags:
          qr: 1
          rd: 1
          ra: 1
        qcount: 1
        acount: 1
        auth_count: 0
        addl_count: 0
      question:
        domain: req.question.domain
        qtype: req.question.qtype
        qclass: req.question.qclass
      answer:
        name: 0xc00c
        qtype: req.question.qtype
        qclass: req.question.qclass
        ttl: 1
        data_length: 4
        data: '127.0.0.1'
    )
    
    @server.send(res, 0, res.length, remote_info.port, remote_info.address)
    
    # packet = new Buffer(1024)
    # 
    # write_string = (str, offset) ->
    #   packet.writeUInt8(str.length, offset)
    #   new Buffer(str, 'ascii').copy(packet, offset + 1, 0, str.length)
    # 
    # write_ip = (ip, offset) ->
    #   i = ip.split('.')
    #   packet.writeUInt8(parseInt(i[0]), offset)
    #   packet.writeUInt8(parseInt(i[1]), offset + 1)
    #   packet.writeUInt8(parseInt(i[2]), offset + 2)
    #   packet.writeUInt8(parseInt(i[3]), offset + 3)
    # 
    # packet.writeUInt16BE(parsed.qid, 0)
    # packet.writeUInt16BE(0x8180, 2)
    # packet.writeUInt16BE(1, 4) # question count
    # packet.writeUInt16BE(1, 6) # answer count
    # packet.writeUInt16BE(0, 8)
    # packet.writeUInt16BE(0, 10)
    # 
    # offset = 12
    # 
    # for d in parsed.domain.split('.')
    #   write_string(d, offset)
    #   offset += 1 + d.length
    # 
    # packet.writeUInt8(0, offset++)
    # packet.writeUInt16BE(parsed.qtype, offset)
    # packet.writeUInt16BE(1, offset + 2)
    # 
    # packet.writeUInt8(0xc0, offset + 4)
    # packet.writeUInt8(0x0c, offset + 5)
    # packet.writeUInt16BE(parsed.qtype, offset + 6)
    # packet.writeUInt16BE(1, offset + 8)
    # packet.writeUInt32BE(1, offset + 10) # TTL
    # packet.writeUInt16BE(4, offset + 14) # IP Length
    # write_ip(ip_address, offset + 16)
    # 
    # @server.send(packet, 0, offset + 20, remote_info.port, remote_info.address)
  
  on_message: (msg, remote_info) ->
    req = @parse(msg)
    console.log "#{REQUEST_TYPES[req.question.qtype]} #{req.question.domain}"
    
    return @respond_with('127.0.0.1', remote_info, req) if req.question.qtype in [REQUEST_TYPES.A, REQUEST_TYPES.AAAA, REQUEST_TYPES.CNAME] and req.question.domain is 'foo.dev'
    return @respond_with('127.0.0.1', remote_info, req) if req.question.qtype in [REQUEST_TYPES.A, REQUEST_TYPES.AAAA, REQUEST_TYPES.CNAME] and @axle.match(req.question.domain)?
    @forward_dns(remote_info, msg)
  
  start: ->
    @server.bind(53)
  
  stop: ->
    @server.close()

module.exports = Dns
