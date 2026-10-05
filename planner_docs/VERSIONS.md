# Version and source audit

Verified on 2026-10-03 on Linux / Pop!_OS. The preinstalled self-contained
`jac` reports **0.37.23**. `jac.toml` pins this version; verify `jac --version` before running. No separate
`jac-client` or `jac-scale` pip packages are used.

Sources consulted:

- [Course tutorial](https://jaclang.org/docs/v0.37/tutorials/first-app/build-ai-day-planner)
- [Official documentation](https://jaclang.org/docs/latest)
- Official complete example, exported **by this exact binary** with
  `jac create /tmp/student-planner-official --awesome --skip`.
  Its upstream source is `jac/examples/jaclang_org/` in the Jac source tree.
- `jac guide tutorials/first-app/build-ai-day-planner`
- `jac guide tutorials/first-app/day-planner-04-frontend`
- `jac guide jac-sv-microservices`
- `jac guide jac-mobile-app` and `jac guide tutorials/fullstack/mobile`
- `jac guide quick-guide/install`, `jac guide reference/config`

The course URL was not readable through the web reader. The installed binary's
bundled tutorial and source were used instead; they match 0.37.23. The latest
website is not assumed to match an older tutorial snapshot. Some bundled prose
still mentions removed `cl` markers; the examples and compiler use inferred
placement, which this project follows.

The official example's `jac.toml`, `arch.jac`, `core/`, `web/main.jac`,
`mobile/main.jac`, mobile README, `cli/main.jac` and CLI command/bridge files were
inspected. This project borrows the multi-app layout and public service boundary,
not the website's content or features. Web imports the public service using Jac's
automatic bridge. CLI and Mobile use its documented HTTP function endpoint,
including the actual observed `data.result` response envelope, to make the
backend address explicit. SQLite is accessed only from Jac service code.

## Tested toolchain

- Jac binary: **0.37.23** (bundles its Python runtime, Bun and client/server compiler).
- Web: React/React DOM **19.3.0**, Vite **6.4.3**, React Native Web **0.21.2**.
  Direct web dependencies are pinned in `jac.toml`.
- Jac-provisioned native scaffold: Expo **57.0.26** (SDK 57), React Native
  **0.86.3**, React **19.2.3**, Babel preset Expo **57.0.13**.
- Jac-managed Bun **1.3.11**; native export provisions Node **22.23.2**.
  System Node 18 is not used for this build.
- Playwright **1.58.0** / Chromium 145 for browser tests; Python 3.13.13 for test
  orchestration (Python 3.10+ is sufficient for the scripts).

`jac setup mobile` generates the matching Expo package manifest. Its resolved
native dependency lock is recorded in `planner_docs/mobile.bun.lock`; the web
lock is recorded in `planner_docs/web.bun.lock`. These are reproducibility
snapshots, not generated app source. The normal setup command provisions the
native dependencies from Jac's SDK-matched constraints; compare the recorded
versions if resolving at a later date.

## 0.37.23 native dev workaround

The official `jac run --dev mobile` compiles and starts Metro, but its helper
starts `jac run --serve --no-client mobile/main.jac`. In this version the latter
is dispatched as a native app build, unexpectedly attempting Android tooling.
This was observed during execution and confirmed in the bundled source:
`client/targets/impl/mobile_target.impl.jac` and
`client/targets/client_dev_common.jac` / `server/sv_client.jac`.

`planner_tools/mobile.jac` uses the **same Jac compiler with `native=True`**,
native staging, entry generator and Expo executable resolver. It omits the
unneeded backend child and launches Expo Go explicitly. No generated application
JS is checked in. This adapter deliberately depends on **0.37.23 internal build
APIs** and must be reviewed before upgrading Jac. Restart it after Jac edits;
this small adapter does not implement Jac file watching.

No Mac is needed to compile JS or use a compatible Expo Go app. An actual signed
IPA or standalone iOS native build still requires macOS/Xcode or a configured
remote EAS build with the relevant Apple/Expo accounts. Those were not run.
