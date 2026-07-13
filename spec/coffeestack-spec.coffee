fs = require 'fs'
path = require 'path'
temp = require './helpers/temp'
{convertLine, convertStackTrace, getCacheDirectory, setCacheDirectory} = require '../index'

temp.track()

describe 'CoffeeStack', ->
  describe 'convertLine(filePath, line, column)', ->
    describe 'when the path is to a CoffeeScript file', ->
      it 'converts the JavaScript line and column to a valid CoffeeScript line and column', ->
        filePath = path.join(__dirname, 'fixtures', 'test.coffee')
        expect(convertLine(filePath, 4, 2)).toEqual {line: 1, column: 0, source: filePath}
        expect(convertLine(filePath, 10, 13)).toEqual {line: 7, column: 4, source: filePath}

      describe 'when the file has syntax errors', ->
        it 'returns null', ->
          filePath = path.join(__dirname, 'fixtures', 'invalid.coffee')
          expect(convertLine(filePath, 1, 2)).toBeNull()

    describe 'when the path is to a JavaScript file', ->
      describe 'when a source map exists for the file', ->
        it 'reads the source map instead of generating one', ->
          filePath = path.join(__dirname, 'fixtures', 'js-with-map.js')
          sourcePath = path.join(__dirname, 'fixtures', 'js-with-map.coffee')
          expect(convertLine(filePath, 9, 14)).toEqual {line: 3, column: 17, source: sourcePath}

        describe 'when the source map is invalid', ->
          it 'returns null', ->
            filePath = path.join(__dirname, 'fixtures', 'invalid.js')
            expect(convertLine(filePath, 1, 1)).toBeNull()

      describe 'when a source map does not exist for the file', ->
        it 'returns null', ->
          filePath = path.join(__dirname, 'fixtures', 'no-map.js')
          expect(convertLine(filePath, 1, 1)).toBeNull()

  describe 'convertStackTrace(stackTrace)', ->
    it 'maps JavaScript lines to their CoffeeScript lines', ->
      jsPath = path.join(__dirname, 'fixtures', 'js-with-map.js')
      coffeePath = path.join(__dirname, 'fixtures', 'js-with-map.coffee')
      stackTrace = "Error: this is an error\n    at fail (#{jsPath}:9:14)"

      expect(convertStackTrace(stackTrace)).toBe "Error: this is an error\n    at fail (#{coffeePath}:3:17)"

  describe 'source map caching', ->
    it 'stores compiled source maps and uses them on subsequeunt calls', ->
      CoffeeScript = require 'coffeescript'
      spyOn(CoffeeScript, 'compile').and.callThrough()

      cacheDir = temp.mkdirSync('coffeestack-cache')
      setCacheDirectory(cacheDir)
      expect(getCacheDirectory()).toBe cacheDir

      filePath = path.join(__dirname, 'fixtures', 'test.coffee')
      expect(convertLine(filePath, 4, 2)).toEqual {line: 1, column: 0, source: filePath}
      expect(CoffeeScript.compile.calls.count()).toBe 1

      expect(convertLine(filePath, 4, 2)).toEqual {line: 1, column: 0, source: filePath}
      expect(CoffeeScript.compile.calls.count()).toBe 1

  it "prevents errors from being thrown by CoffeeScript's Error.prepareStackTrace", ->
    convertStackTrace """
      Error: this is an error
        at Test.module.exports.Test.fail (#{__dirname}/fixtures/does-not-exist.coffee:10:15)
    """

    filePath = path.join(temp.mkdirSync(), 'file.coffee')
    fs.writeFileSync filePath, "module.exports = -> throw new Error('hello world')"
    throwsAnError = require(filePath)
    fs.unlinkSync(filePath)

    caughtError = null
    try
      throwsAnError()
    catch error
      caughtError = error
    expect(caughtError.message).toBe 'hello world'
    expect(-> caughtError.stack).not.toThrow()
    expect(caughtError.stack.toString()).toContain(filePath)
