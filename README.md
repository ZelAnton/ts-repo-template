# __ProjectName__

__Description__

## Requirements

- Node.js 24 (Krypton, LTS) or later (the floor is declared in `package.json`
  `engines` and `.nvmrc`; npm warns on a mismatch)

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
sha256sum -c SHA256SUMS        # Linux
shasum -a 256 -c SHA256SUMS    # macOS
```

```pwsh
# Windows: compare against the hash listed in SHA256SUMS
# (Get-FileHash prints uppercase hex; the comparison is case-insensitive)
Get-FileHash *.tgz -Algorithm SHA256
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the version history.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for build/test instructions and
conventions. To report a security issue, follow [SECURITY.md](SECURITY.md) —
please do not open a public issue.

## License

This project is licensed under the [MIT License](LICENSE).
