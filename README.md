# Student Planner

**Extra Credit 1 — Personal Planning App in Jac**  
**Author:** Lianjie Yuan · **UMID:** `26304008`  
**Due:** October 5, 2026 · Individual project

A calm place to organize coursework, research, graduate applications and personal
errands. One Jac backend powers an interactive web dashboard, a real Jac / React
Native mobile app and a Jac CLI. No AI account or API key is needed.

## Install and run

Tested with **Jac 0.37.23 on Linux / Pop!_OS**. Use the self-contained binary,
not an older pip installation. It includes the language runtime and Bun; it
provisions its local PostgreSQL runtime and native JS tooling as needed. Initial
installation needs internet access and a writable user cache.

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh \
  | bash -s -- --version 0.37.23
export PATH="$HOME/.local/bin:$PATH"
jac --version                  # must report 0.37.23
jac install
jac run                        # run from this repository's root
```

Open **http://localhost:8000**. In Jac 0.37.23, plain `jac run` starts the
web-app kind in development mode: Web listens on **0.0.0.0:8000**, proxying the
colocated planner service on internal API port **8001**. Keep this terminal
running; Ctrl+C stops it. Clients use the **8000 origin**, not the internal port.
Use `jac run --port 8100` if 8000 is occupied and give clients that same port.
For a built Web bundle and API on a single port, use `jac run --no-dev`.

The initial task list is empty. No demo tasks are silently inserted.
Do not install the pre-existing robotics `pyproject.toml` when working in the
original workspace; `jac install` is the planner's installation command.

## Features and data rules

- UUID tasks with title, category, due date, optional time, priority, estimated
  minutes, completion and notes. Add, edit, delete, complete and restore.
- Today, Next 7 Days, Overdue and All Tasks; category and status filters;
  completion statistics; loading, empty and network error states.
- New York time everywhere: **America/New_York**, regardless of browser/phone
  timezone. Date format `YYYY-MM-DD`; optional 24-hour time `HH:MM`.
- Today is the server's local calendar date. Next 7 Days is **today through
  today + 6 days**, including completed tasks unless filtered. Overdue excludes
  completed tasks. All-day tasks become overdue at the next local midnight;
  timed tasks become overdue strictly after their deadline.
- Nonexistent spring-forward times are rejected. Repeated fall-back times mean
  the **first occurrence** (`fold=0`). Date-only tasks are not shifted to UTC.
- Integer task estimates: 1–10080 minutes. Titles: 1–200 nonblank characters;
  notes: at most 4000. IDs are immutable, unknown fields and invalid dates fail
  with readable errors. Invalid edits do not partially change a task.
- Study recommendation considers **all open tasks**, independent of dashboard
  filters. Earliest deadline first; ties use High/Medium/Low, then shorter tasks
  and ID. It schedules whole tasks greedily within 1–1440 available minutes,
  skips oversized tasks, and explains both selected and omitted tasks. This
  is a transparent heuristic, not an optimal scheduler or a promise that an
  already-overdue deadline can be met. Rebuild the plan after external changes.

Use Refresh after another client makes changes; this is not a live push app.

## CLI

In another terminal, from the same repository root:

```bash
jac run cli -- --help
jac run cli -- add "Finish Jac assignment" --due 2026-10-05 --time 17:00 \
  --category Coursework --priority High --minutes 90 --notes "Check the rubric"
jac run cli -- list
jac run cli -- today
jac run cli -- list --view week --category Research --status open
jac run cli -- list --view overdue
jac run cli -- complete TASK_ID
jac run cli -- restore TASK_ID
jac run cli -- edit TASK_ID --changes '{"minutes":45,"notes":"Revised estimate"}'
jac run cli -- plan 120
jac run cli -- delete TASK_ID
```

Replace `TASK_ID` with an ID returned by add/list. CLI output is formatted JSON,
including the same server-filtered tasks displayed in the other clients.

```bash
jac run cli -- --server http://192.168.0.178:8000 today
# Or set this once in the CLI terminal:
export STUDENT_PLANNER_URL=http://192.168.0.178:8000
```

The address is an **origin**, without `/api`. `--server` goes before the command.
Exit codes: 0 success, 2 invalid input, 3 HTTP/network failure. No CLI database is
created. CLI deletion is explicit and immediate; Web asks for confirmation.

## Mobile: Linux + iPhone + Expo Go

`mobile/main.jac` is a genuine `kind = "mobile"` Jac entry, using native
`@jac/mobui` components. It compiles to React Native, not a webview. It can show
Today / All Tasks, quickly add category/priority/date/estimate, complete/restore,
refresh and display network errors. Detailed time/notes editing is on Web/CLI.

Keep **`jac run` running first**. In a second terminal:

```bash
jac setup mobile
jac run planner_tools/mobile.jac
```

This compiles the Jac native app and starts **Expo Go / Metro on port 8081**.
Use iPhone Camera to scan the terminal QR; open it in **Expo Go**. The generated
project uses **Expo SDK 57**, React Native 0.86.3 and React 19.2.3. Expo Go on your
phone must support SDK 57. No Expo login, Mac or Xcode is needed for this route.
The device compatibility check is still yours to perform; an iOS bundle export
is not proof that a particular installed Expo Go version will accept it.

The small Jac launcher avoids an observed 0.37.23 bug in the official
`jac run --dev mobile` extra backend process; details and source evidence are in
[the version audit](planner_docs/VERSIONS.md). It uses Jac's official native
compiler/staging routines. **Restart it after editing `.jac` files.**

### Connect the phone to the same data

1. Connect computer and iPhone to the same non-isolated Wi-Fi network.
2. On Linux, run `ip -4 route get 1.1.1.1` and use the address after `src`.
   The tested computer used **192.168.0.178**; your current address may differ.
3. In the mobile app's **Backend URL** field enter e.g.
   `http://192.168.0.178:8000`, then tap **Connect / Refresh**.
   **`localhost` / `127.0.0.1` on iPhone means the iPhone, not your computer.**
4. Allow Expo Go's iOS **Local Network** permission. If needed, verify that
   `http://COMPUTER_IP:8000` opens in iPhone Safari as a connectivity check only;
   Safari is not the mobile app submission.
5. Linux must listen on the LAN: `ss -ltn | grep -E ':8000|:8081'`.
   If a firewall blocks it, inspect `sudo ufw status` and allow only your actual
   LAN subnet to TCP 8000 and 8081, e.g. `sudo ufw allow from 192.168.0.0/24 to any
   port 8000 proto tcp` and the equivalent for 8081. Do **not** disable the whole
   firewall. Guest Wi-Fi isolation/VPN routing may need changing instead.

No firewall rules are changed by this project. The mobile URL is session state;
re-enter it after a full restart. The phone stores no task files.

To verify the native iOS JS/Hermes build without a phone:

```bash
jac run planner_tools/mobile.jac --check
```

The artifact is generated under `.jac/mobile-rn/ios-check/` (ignored). This
checks JS bundling, not Apple signing or iOS runtime behavior. A standalone IPA
requires macOS/Xcode or an account-configured **remote EAS build** and Apple
signing. Neither is performed here. If SDK 57 Expo Go is unavailable, use an
SDK-matched Expo development build through those tools; do not downgrade Expo
alone without rechecking Jac's runtime/dependency compatibility.

## Architecture and persistence

```text
web/main.jac ── Jac generated service bridge ─┐
mobile/main.jac → core/remote.jac ── HTTP ─────┼→ core/service.jac (Jac service)
cli/main.jac ── HTTP ────────────────────────┘       ↓
                                      core/logic.jac + core/storage.jac
                                                   ↓
                                      .planner-data/tasks.sqlite3
```

`POST /api/planner/function/planner` accepts `{ "action": "list", "payload": {} }`.
Jac wraps successful function results in `data.result`; domain errors return
`{ "ok": false, "error": "..." }` there. The UI/CLI unwrap and display them.
Only the server opens SQLite. Each mutation is an atomic transaction with bound
SQL parameters. The task database survives process restarts; neither a client
restart nor building the app clears it. Override its absolute path with
`STUDENT_PLANNER_DB=/path/to/tasks.sqlite3 jac run` for backups or isolated tests.
Back up that file while the server is stopped. Jac separately maintains its own
runtime/identity PostgreSQL database in the user's Jac cache; it is not the
planner task database and is not submitted.

This is a **single-user coursework app on a trusted local network**, without
per-user authorization. Public planner endpoints share one dataset. Do not
publish this configuration to the internet. No secrets are required or included.

## Verification

```bash
jac check
jac test
python3 planner_tests/restart.py
```

The Jac tests cover validation, date/UTC/DST boundaries, filtering, transaction
rollback, IDs, persistence and budget behavior. The Python restart test starts
and stops real Jac servers on port 8020 using an isolated temporary task DB.

For actual Web + mobile-screen cross-client automation (requires Python 3.10+):

```bash
python3 -m venv /tmp/planner-browser-env
/tmp/planner-browser-env/bin/pip install -r planner_tests/requirements.txt
/tmp/planner-browser-env/bin/playwright install chromium
jac build mobile --platform web
# Separate terminal; leave jac run running as well:
python3 -m http.server 8010 --bind 127.0.0.1 --directory .jac/client/mobile/dist
# Another terminal:
/tmp/planner-browser-env/bin/python planner_tests/e2e.py
```

The browser suite creates synthetic tasks and cleans up only its own IDs. It
checks CLI → Web → Mobile screen → CLI/Web, edits, completion/restoration, native
screen quick-add, Web add, delete/cancel confirmation and network errors.
**React Native Web testing is not an iPhone test.** See the exact results and
remaining device checks in [VALIDATION.md](planner_docs/VALIDATION.md).

## Two-minute demo

1. Start `jac run`; show the empty dashboard and add a task due today via CLI.
2. Refresh Web; edit its notes and estimate. Filter by its category.
3. In Expo Go, connect to the computer's address, refresh and complete that task.
4. Refresh Web and run `jac run cli -- today`; both should show it completed.
5. Restore it. Add a 180-minute task and build a 60-minute plan; demonstrate that
   the oversized task is explained under Not scheduled.
6. Stop/restart `jac run` and refresh; task IDs and state should remain unchanged.
7. Demonstrate the delete confirmation and Mobile's invalid-server error.

## Submission

Replace **YOUR_UMID** above. Complete the physical iPhone checklist in
[VALIDATION.md](planner_docs/VALIDATION.md). Review the exported source before
creating your GitHub repository and submitting its link to Canvas.

This workspace originally contained a robotics project. Its files were retained,
and its original README is preserved at
`planner_docs/README.original-robotics.md` **in the original workspace only**.
To prepare a clean, standalone coursework repository:

```bash
python3 planner_tools/export.py /tmp/student-planner-submission
cd /tmp/student-planner-submission
jac install
jac run
```

The exporter refuses an existing destination and copies only coursework source,
tests and docs. It excludes original robotics files, task databases, virtual
environments, `.jac`, `node_modules`, caches and secrets. This exported directory
is the recommended GitHub repository root; **`jac run` works there too**.

Suggested commit message:
`feat: add Jac Student Planner with shared web, mobile and CLI workflows`

No repository push, public deployment or Canvas submission is performed by the
project tools.
