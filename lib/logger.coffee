require 'colors'

LEVELS = [
  'debug'
  'info'
  'notice'
  'warning'
  'error'
  'critical'
  'alert'
  'emergency'
]
LEVEL_COLORS = {
  debug: 'magenta'
  info: 'green'
  notice: 'green'
  warning: 'yellow'
  error: 'red'
  critical: 'red'
  alert: 'red'
  emergency: 'red'
}

exports.log = (level) ->
  level = level.toLowerCase()
  
  args = Array::slice.call(arguments, 1)
  args[0] = '[' + 'axle'.cyan + '] ' + level[LEVEL_COLORS[level]] + ' ' + args[0]
  console.log.apply(console, args)

LEVELS.forEach (level) ->
  exports[level] = -> exports.log.apply(null, [level].concat(Array::slice.call(arguments)))

['grey', 'black', 'yellow', 'red', 'green', 'blue', 'white', 'cyan', 'magenta'].forEach (color) ->
  exports[color] = (value) -> value.toString()[color]
