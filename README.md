# __ProjectName__

__Description__

## Requirements

- Node.js 24 (Krypton, LTS) or later — includes npm, which drives everything
  (installs dependencies, runs build/lint/type/test via `package.json` scripts)

## Installation

Available on [npm](https://www.npmjs.com/package/__PackageName__).

```sh
npm install __PackageName__
```

## Usage

```typescript
import { greet } from "__PackageName__";

console.log(greet("World")); // -> "Hello, World!"
```

## Verifying the package

Each GitHub Release ships a `SHA256SUMS` file alongside the published tarball.
Download them into the same directory, then:

```sh
sha256sum -c SHA256SUMS
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the version history.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for build/test instructions and
conventions. To report a security issue, follow [SECURITY.md](SECURITY.md) —
please do not open a public issue.

## License

This project is licensed under the [MIT License](LICENSE).
