# wayplug

`wayplug` is an experimental native Wayland plugin UI hosting library.

The goal is to provide a small, stable C ABI that hosts and plugin formats can
use to support embedded Wayland plugin editors without relying on X11/XEmbed.
The implementation language is intentionally left open, but the public boundary
should remain plain C so hosts such as Carla and plugins written in C, C++,
Rust, Zig, and other languages can bind to it.

The initial implementation is planned in Zig with a stable C ABI.

## Scope

The first target is embedded plugin UI hosting:

- host creates or owns a Wayland surface region for a plugin editor
- plugin connects to a host-managed delegated Wayland connection
- plugin creates a child surface/subsurface
- host controls placement, size, lifecycle, and event integration

Floating plugin windows are a related but separate problem. For floating
windows, `xdg_foreign_unstable_v2` is likely the right compositor protocol for
setting a plugin editor as transient for a host window.

## License

`wayplug` uses BSD-3-Clause. This keeps the project compatible with permissive
open source use and with future work derived from the BSD-3-Clause
`wayland-server-delegate` project.

## Build

```sh
zig build
zig build test
```

## Documentation

- [Architecture](docs/archtecture.md)
- [Data-Oriented Design](docs/dod.md)
- [Style Guide](docs/style-guide.md)
- [Design Notes](docs/design-notes.md)
- [Protocol Landscape](docs/protocol-landscape.md)
- [wayland-server-delegate Architecture](docs/wsd-architecture.md)
- [C ABI Sketch](docs/c-abi-sketch.md)
- [Roadmap](docs/roadmap.md)
