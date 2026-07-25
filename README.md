# coffeestack

Converts JavaScript stack traces to their original CoffeeScript locations.

## Features

- **Stack conversion**: maps JavaScript stack frames back to CoffeeScript source locations.
- **Source map support**: reads adjacent source maps or generates maps directly from CoffeeScript files.
- **Persistent caching**: optionally caches generated source maps to reduce repeated compilation work.
- **Safe fallback**: leaves stack frames unchanged when source files or maps cannot be resolved.

## Installation

```sh
npm install @lumine-code/coffeestack
```

## Usage

```js
const {convertStackTrace, setCacheDirectory} = require('@lumine-code/coffeestack')

setCacheDirectory('/path/to/cache')

try {
  throw new Error('example')
} catch (error) {
  console.error(convertStackTrace(error.stack))
}
```

## Building

```sh
npm install
npm test
```

## Contributing

Got ideas to make this package better, found a bug, or want to help add new features? Just drop your thoughts on GitHub. Any feedback is welcome!
