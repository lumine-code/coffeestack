crypto = require 'crypto'
fs = require 'fs'
path = require 'path'

CoffeeScriptVersion = null # defer until used
CoffeeScript = null # defer until used
SourceMapConsumer = null # defer until used

cachePath = null

getCachePath = (code) ->
  return unless cachePath

  digest = crypto.createHash('sha1').update(code, 'utf8').digest('hex')
  CoffeeScriptVersion ?= require('coffeescript/package.json').version
  path.join(cachePath, CoffeeScriptVersion, "#{digest}.json")

getCachedSourceMap = (codeCachePath) ->
  if isFileSync(codeCachePath)
    try
      return fs.readFileSync(codeCachePath, 'utf8')

  return

writeSourceMapToCache = (codeCachePath, sourceMap) ->
  if codeCachePath
    try
      fs.mkdirSync(path.dirname(codeCachePath), {recursive: true})
      fs.writeFileSync(codeCachePath, sourceMap)

  return

loadCoffeeScript = ->
  coffee = require 'coffeescript'

  # Work around for https://github.com/jashkenas/coffeescript/issues/3890
  coffeePrepareStackTrace = Error.prepareStackTrace
  if coffeePrepareStackTrace?
    Error.prepareStackTrace = (error, stack) ->
      try
        return coffeePrepareStackTrace(error, stack)
      catch coffeeError
        return stack

  coffee

compileSourceMap = (code, filePath, codeCachePath) ->
  CoffeeScript ?= loadCoffeeScript()
  {v3SourceMap} = CoffeeScript.compile(code, {sourceMap: true, filename: filePath})
  writeSourceMapToCache(codeCachePath, v3SourceMap)
  v3SourceMap

getSourceMapPosition = (sourceMapContents, line, column)->
  SourceMapConsumer ?= require('source-map-js').SourceMapConsumer
  if typeof sourceMapContents is 'string'
    sourceMapContents = JSON.parse(sourceMapContents)
  sourceMap = new SourceMapConsumer(sourceMapContents)
  sourceMap.originalPositionFor({line, column})

isFileSync = (filePath) ->
  try
    fs.statSync(filePath).isFile()
  catch
    false

convertLine = (filePath, line, column, sourceMaps={}) ->
  try
    unless sourceMapContents = sourceMaps[filePath]
      if path.extname(filePath) is '.js'
        sourceMapPath = "#{filePath}.map"
        sourceMapContents =  fs.readFileSync(sourceMapPath, 'utf8')
      else
        code = fs.readFileSync(filePath, 'utf8')
        codeCachePath = getCachePath(code)
        sourceMapContents = getCachedSourceMap(codeCachePath)
        sourceMapContents ?= compileSourceMap(code, filePath, codeCachePath)

    if sourceMapContents
      sourceMaps[filePath] = sourceMapContents
      position = getSourceMapPosition(sourceMapContents, Number(line), Number(column))
      if position.line? and position.column?
        if position.source and position.source isnt '.'
          source = path.resolve(filePath, '..',  position.source)
        else
          source = filePath
        return {line: position.line, column: position.column, source}

  null

convertStackTrace = (stackTrace, sourceMaps={}) ->
  return stackTrace unless stackTrace

  convertedLines = []
  atLinePattern = /^(\s+at .* )\((.*):(\d+):(\d+)\)/
  for stackTraceLine in stackTrace.split('\n')
    if match = atLinePattern.exec(stackTraceLine)
      filePath = match[2]
      line = match[3]
      column = match[4]
      if path.extname(filePath) is '.js'
        mappedLine = convertLine(filePath, line, column, sourceMaps)
      if mappedLine?
        convertedLines.push("#{match[1]}(#{mappedLine.source}:#{mappedLine.line}:#{mappedLine.column})")
      else
        convertedLines.push(stackTraceLine)
    else
      convertedLines.push(stackTraceLine)

  convertedLines.join('\n')

exports.convertLine = convertLine
exports.convertStackTrace = convertStackTrace
exports.setCacheDirectory = (newCachePath) -> cachePath = newCachePath
exports.getCacheDirectory = -> cachePath
