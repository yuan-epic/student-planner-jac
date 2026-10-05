# Validation record

Automated checks executed on **2026-10-03**, Linux / Pop!_OS, Jac **0.37.23**,
using synthetic test tasks. No physical iPhone was connected to that automated
test session. Physical iPhone results below were reported by **Lianjie Yuan**
on **2026-10-04** and are recorded separately from the automated checks.

| Check | Result / evidence |
|---|---|
| Root `jac run` | Passed in original workspace and clean coursework copy; Web 8000 proxies Jac API 8001. |
| `jac run --no-dev` | Passed in real-process restart test; built Web/API serve together on 8020. |
| `jac check` | Passed, all four app programs; warnings include explicit heterogeneous JSON `any` annotations. |
| `jac test` | 5 behavioral tests passed, also in clean copy. |
| CLI add → Web | Passed in Chromium, actual UI row and matching UUID. |
| Web edit → CLI/Mobile | Passed; title/notes saved and visible across clients. |
| Mobile screen complete → Web/CLI | Passed in compiled React Native Web screen, same UUID and completed state. **Not a native iPhone test.** |
| Mobile screen quick add | Passed, Web refresh sees the same new server task. |
| Web add/complete/restore/delete | Passed, including cancellation and acceptance of delete confirmation. |
| Persistence across processes | Passed: stop Jac, start Jac again, verify same ID, title/notes and completion. Isolated SQLite database. |
| Date/status/category filters | Passed at New York midnight, UTC day mismatch, timed deadline equality, seven-day endpoint, completed exclusions and category mismatch. |
| DST | Passed: nonexistent spring-forward time rejected; first repeated fall-back occurrence used. |
| Budget | Passed including oversized tasks, completed exclusion, priority ties, invalid budgets and every budget from 1 through 150 minutes. |
| Invalid input / atomic edits | Passed; blank titles, malformed dates/time, invalid categories/priority, non-integer/bool minutes and invalid completion rejected; previous task remains unchanged. |
| Server unavailable | Passed: Web/mobile screen show errors; CLI reports URL/cause and exits 3. |
| Browser runtime | No uncaught JavaScript errors during successful interaction flows. |
| `jac setup mobile` | Passed; actual Expo 57 / React Native 0.86.3 dependencies installed. |
| Native Expo launcher | Starts Metro on 8081 without Android SDK/build or duplicate backend. |
| iOS native JS build | Passed twice, including clean copy; `jac run planner_tools/mobile.jac --check` produces a ~2.5 MB iOS Hermes `.hbc` and metadata. |
| iPhone Expo Go interaction | **PASS — manually verified by Lianjie Yuan, reported 2026-10-04.** iPhone 16 Pro, iOS 26.6.2, Expo Go 57.0.9; native launch, backend connection, shared-task updates and error recovery passed. See device details and the port clarification below. |
| Signed iOS app / App Store build | **Not performed.** Requires additional platform/account setup. |

## Reproduction details

The clean project was generated with `planner_tools/export.py` into
`/tmp/student-planner-clean-verify`. It contained only allowed coursework source,
configuration, tests and documentation: no old robotics `pyproject.toml`, project
`.jac`, task database, virtual environment, `node_modules` or built client files.
`jac install`, `jac check`, `jac test`, plain `jac run`, mobile setup/build,
the browser cross-client suite and the restart test were run from that copy.
The installed Jac binary and machine-level tool/package download caches were
reused; this is not a fresh OS/VM test. The browser test runner lived in a
separate temporary venv installed from `planner_tests/requirements.txt`.

The native export can print a Bun color-environment warning when `NO_COLOR` and
`FORCE_COLOR` are both set by the terminal environment; the exporter finishes
with exit code 0 and writes Hermes bytecode. Jac's installer can also warn about
its default dev dependencies appearing alongside explicitly pinned versions.
These warnings did not prevent installation or the recorded checks.

## Physical iPhone acceptance checklist

Manual test results reported by **Lianjie Yuan on 2026-10-04** on a physical
phone running Expo Go. These are user-reported device results, not inferred
from the browser preview or Hermes bundle export. Device/version strings are
recorded as supplied by the tester.

- iPhone model / iOS version: **iPhone 16 Pro**, model number **MYNH3ZP/A**;
  **iOS 26.6.2**.
- Expo Go version / supports SDK 57: **PASS** — **Expo Go 57.0.9** successfully
  opened this project's SDK 57 app.
- Computer LAN address used: **192.168.0.178**.
- Scan `jac run planner_tools/mobile.jac` QR and launch native app: **PASS** —
  successfully scanned the QR code and saw Student Planner inside Expo Go.
- Allow local network access; connect to the shared backend: **PASS** — local
  network permission was granted and the tester reported a successful connection.
  See the address clarification below.
- CLI creates task; phone Refresh shows matching UUID: **PASS** — reported that
  the CLI-created task appeared on the phone with the matching UUID.
- Phone completes task; Web Refresh and CLI list show completed: **PASS** —
  reported that completion on the phone was reflected in both Web and CLI.
- Phone restores task and quickly adds another; Web sees both changes: **PASS** —
  reported that restoration and quick-add changes appeared on Web.
- Set a wrong backend address; error and recovery work: **PASS** — reported that
  an incorrect address produced an error and correcting it restored access.
