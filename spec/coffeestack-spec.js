var convertLine, convertStackTrace, fs, getCacheDirectory, path, setCacheDirectory, temp;

fs = require('fs');

path = require('path');

temp = require('./helpers/temp');

({convertLine, convertStackTrace, getCacheDirectory, setCacheDirectory} = require('../index'));

temp.track();

describe('CoffeeStack', function() {
  afterEach(function() {
    return setCacheDirectory(null);
  });
  describe('convertLine(filePath, line, column)', function() {
    describe('when the path is to a CoffeeScript file', function() {
      it('converts the JavaScript line and column to a valid CoffeeScript line and column', function() {
        var filePath;
        filePath = path.join(__dirname, 'fixtures', 'test.coffee');
        expect(convertLine(filePath, 4, 2)).toEqual({
          line: 1,
          column: 0,
          source: filePath
        });
        return expect(convertLine(filePath, 10, 13)).toEqual({
          line: 7,
          column: 4,
          source: filePath
        });
      });
      return describe('when the file has syntax errors', function() {
        return it('returns null', function() {
          var filePath;
          filePath = path.join(__dirname, 'fixtures', 'invalid.coffee');
          return expect(convertLine(filePath, 1, 2)).toBeNull();
        });
      });
    });
    describe('when the path is to a JavaScript file', function() {
      describe('when a source map exists for the file', function() {
        it('reads the source map instead of generating one', function() {
          var filePath, sourcePath;
          filePath = path.join(__dirname, 'fixtures', 'js-with-map.js');
          sourcePath = path.join(__dirname, 'fixtures', 'js-with-map.coffee');
          return expect(convertLine(filePath, 9, 14)).toEqual({
            line: 3,
            column: 17,
            source: sourcePath
          });
        });
        return describe('when the source map is invalid', function() {
          return it('returns null', function() {
            var filePath;
            filePath = path.join(__dirname, 'fixtures', 'invalid.js');
            return expect(convertLine(filePath, 1, 1)).toBeNull();
          });
        });
      });
      return describe('when a source map does not exist for the file', function() {
        return it('returns null', function() {
          var filePath;
          filePath = path.join(__dirname, 'fixtures', 'no-map.js');
          return expect(convertLine(filePath, 1, 1)).toBeNull();
        });
      });
    });
    it('uses a caller-provided source map without reading it from disk', function() {
      var filePath, sourceMap;
      filePath = path.join(__dirname, 'fixtures', 'virtual.js');
      sourceMap = fs.readFileSync(path.join(__dirname, 'fixtures', 'js-with-map.js.map'), 'utf8');
      return expect(convertLine(filePath, 9, 14, {
        [`${filePath}`]: sourceMap
      })).toEqual({
        line: 3,
        column: 17,
        source: path.join(__dirname, 'fixtures', 'js-with-map.coffee')
      });
    });
    return it('reuses a generated source map supplied cache object', function() {
      var CoffeeScript, filePath, sourceMaps;
      CoffeeScript = require('coffeescript');
      spyOn(CoffeeScript, 'compile').and.callThrough();
      sourceMaps = {};
      filePath = path.join(__dirname, 'fixtures', 'test.coffee');
      expect(convertLine(filePath, 4, 2, sourceMaps)).toEqual({
        line: 1,
        column: 0,
        source: filePath
      });
      expect(convertLine(filePath, 10, 13, sourceMaps)).toEqual({
        line: 7,
        column: 4,
        source: filePath
      });
      return expect(CoffeeScript.compile.calls.count()).toBe(1);
    });
  });
  describe('convertStackTrace(stackTrace)', function() {
    it('maps JavaScript lines to their CoffeeScript lines', function() {
      var coffeePath, jsPath, stackTrace;
      jsPath = path.join(__dirname, 'fixtures', 'js-with-map.js');
      coffeePath = path.join(__dirname, 'fixtures', 'js-with-map.coffee');
      stackTrace = `Error: this is an error\n    at fail (${jsPath}:9:14)`;
      return expect(convertStackTrace(stackTrace)).toBe(`Error: this is an error\n    at fail (${coffeePath}:3:17)`);
    });
    it('preserves unrecognized and unmappable stack frames', function() {
      var missingPath, stackTrace;
      missingPath = path.join(__dirname, 'fixtures', 'missing.js');
      stackTrace = `Error: this is an error\n    at direct.js:1:2\n    at missing (${missingPath}:3:4)`;
      return expect(convertStackTrace(stackTrace)).toBe(stackTrace);
    });
    it('maps every convertible frame in a stack trace', function() {
      var coffeePath, jsPath, stackTrace;
      jsPath = path.join(__dirname, 'fixtures', 'js-with-map.js');
      coffeePath = path.join(__dirname, 'fixtures', 'js-with-map.coffee');
      stackTrace = `Error: this is an error\n    at first (${jsPath}:9:14)\n    at second (${jsPath}:9:14)`;
      return expect(convertStackTrace(stackTrace)).toBe(`Error: this is an error\n    at first (${coffeePath}:3:17)\n    at second (${coffeePath}:3:17)`);
    });
    return it('returns falsy stack values unchanged', function() {
      expect(convertStackTrace(null)).toBeNull();
      expect(convertStackTrace(void 0)).toBeUndefined();
      return expect(convertStackTrace('')).toBe('');
    });
  });
  describe('source map caching', function() {
    return it('stores compiled source maps and uses them on subsequeunt calls', function() {
      var CoffeeScript, cacheDir, filePath;
      CoffeeScript = require('coffeescript');
      spyOn(CoffeeScript, 'compile').and.callThrough();
      cacheDir = temp.mkdirSync('coffeestack-cache');
      setCacheDirectory(cacheDir);
      expect(getCacheDirectory()).toBe(cacheDir);
      filePath = path.join(__dirname, 'fixtures', 'test.coffee');
      expect(convertLine(filePath, 4, 2)).toEqual({
        line: 1,
        column: 0,
        source: filePath
      });
      expect(CoffeeScript.compile.calls.count()).toBe(1);
      expect(convertLine(filePath, 4, 2)).toEqual({
        line: 1,
        column: 0,
        source: filePath
      });
      return expect(CoffeeScript.compile.calls.count()).toBe(1);
    });
  });
  return it("prevents errors from being thrown by CoffeeScript's Error.prepareStackTrace", function() {
    var caughtError, error, filePath, throwsAnError;
    convertStackTrace(`Error: this is an error
  at Test.module.exports.Test.fail (${__dirname}/fixtures/does-not-exist.coffee:10:15)`);
    filePath = path.join(temp.mkdirSync(), 'file.coffee');
    fs.writeFileSync(filePath, "module.exports = -> throw new Error('hello world')");
    throwsAnError = require(filePath);
    fs.unlinkSync(filePath);
    caughtError = null;
    try {
      throwsAnError();
    } catch (error1) {
      error = error1;
      caughtError = error;
    }
    expect(caughtError.message).toBe('hello world');
    expect(function() {
      return caughtError.stack;
    }).not.toThrow();
    return expect(caughtError.stack.toString()).toContain(filePath);
  });
});
