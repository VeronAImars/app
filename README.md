# k3sm app

The k3sm macOS app: a status item in the menu bar, plus a window, for
[k3sm](https://k3sm.io). The status item shows while this Mac's k3sm node
daemon is running and hides when the daemon stops.

The app reads state only from `k3sm status -o json`, the machine interface the
k3sm CLI already documents. It never reads daemon files, sockets or the
datastore itself.

This repository is private and early. Today it holds:

- `Sources/K3smStatus`: decodes the status JSON, detects whether this Mac is a
  server or an agent, and applies the visibility rule (show after one running
  reading, hide after two consecutive readings that are not running).
- `Sources/K3smApp`: a minimal AppKit app stub with one status item.
- `Tests/K3smStatusTests`: unit tests over status fixtures copied from k3sm.

## Build

Requires macOS 26 or later on Apple silicon and Swift 6.

```sh
swift build
swift test
hack/build-app.sh out/   # builds and ad-hoc signs out/k3sm.app
hack/ci.sh               # the full gate
```

The bundle id is `io.k3sm.app` and the app logs to the unified log under the
same subsystem. With only the Command Line Tools installed, `swift test` may
need the swift-testing macro plugin path; `hack/ci.sh` adds it for you.

## License

Apache License 2.0. See [LICENSE](LICENSE).
