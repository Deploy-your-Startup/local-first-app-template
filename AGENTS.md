# Template repository rules

This repository is the Copier source for a local-first application. Generated
projects live elsewhere; the working example in `template/` must stay runnable
after rendering.

- `template/` is the project skeleton. Never branch on the owner's machine,
  private hosts, credentials or a specific startup.
- `tests/render_test.sh` renders a disposable project from the committed
  revision and asserts neutral, complete output. `./make.sh check` also lints,
  tests, builds and browser-tests that rendered project. The rendered project's
  `test_ios` needs macOS, Xcode and `cloudflared`, so CI stays Linux and browser
  only.
- iOS shell values are derived from Copier answers: `web_origin` reaches the
  Xcode project and `app_bound_domain` follows it. Never commit a tunnel URL, a
  certificate or a signing team, and never hardcode a machine-specific Xcode
  path.
- Render text is templated with the Factory delimiters
  (`§§deploy_your_startup.<variable>§§`). JavaScript template literals and
  framework syntax stay untouched; do not switch to default Jinja braces.
- Binary assets are committed next to their upstream notice and must not be
  regenerated during rendering.
- Add a vertical slice at a time. Each slice adds executable integration or E2E
  scenarios first, then the code that satisfies them.
- TypeScript services own task logic and persistence on every platform. Do not
  add native databases or move CRUD into Rust.
- Keep `README.md` limited to capabilities that a rendered project actually
  passes in this repository's checks.
