import argparse;
import sys;
import os;
import json;
import from urllib.request { Request, urlopen }
import from urllib.error { URLError, HTTPError }

def main(argv: list[str]) -> int {
    parser = argparse.ArgumentParser(
        prog="jac run cli --",
        description="Student Planner: shared server tasks. All dates use America/New_York."
    );
    parser.add_argument(
        "--server",
        `default=os.environ.get("STUDENT_PLANNER_URL", "http://127.0.0.1:8000"),
        help="Backend origin (or STUDENT_PLANNER_URL)"
    );
    commands = parser.add_subparsers(dest="command", required=True);
    add = commands.add_parser("add", help="Add a task");
    add.add_argument("title");
    add.add_argument("--due", required=True, help="YYYY-MM-DD");
    add.add_argument("--time", `default="", help="Optional HH:MM New York time");
    add.add_argument(
        "--category",
        choices=["Coursework", "Research", "Applications", "Personal"],
        `default="Coursework"
    );
    add.add_argument(
        "--priority", choices=["High", "Medium", "Low"], `default="Medium"
    );
    add.add_argument("--minutes", `type=int, `default=30);
    add.add_argument("--notes", `default="");
    for name in ["list", "today"] {
        sub = commands.add_parser(name, help="List shared tasks");
        sub.add_argument("--category", `default="all");
        sub.add_argument(
            "--status", choices=["all", "open", "completed"], `default="all"
        );
        if name == "list" {
            sub.add_argument(
                "--view", choices=["all", "today", "week", "overdue"], `default="all"
            );
        }
    }
    for name in ["complete", "restore", "delete"] {
        commands.add_parser(name).add_argument("id");
    }
    edit = commands.add_parser("edit", help="Edit fields using a JSON object");
    edit.add_argument("id");
    edit.add_argument("--changes", required=True);
    commands.add_parser(
        "plan", help="Recommend whole tasks within a time budget"
    ).add_argument(
        "minutes", `type=int
    );
    args = parser.parse_args(argv);
    action = args.command;
    payload = {};
    try {
        if action == "add" {
            payload = {
                "title": args.title,
                "due_date": args.due,
                "due_time": args.time,
                "category": args.category,
                "priority": args.priority,
                "minutes": args.minutes,
                "notes": args.notes
            };
        } elif action in ["today", "list"] {
            payload = {
                "view": "today" if action == "today" else args.view,
                "category": args.category,
                "status": args.status
            };
            action = "list";
        } elif action == "plan" {
            payload = {"budget": args.minutes};
        } elif action == "edit" {
            payload = {"id": args.id, "changes": json.loads(args.changes)};
        } else {
            payload = {"id": args.id, "completed": action == "complete"};
            if action == "restore" {
                action = "complete";
            }
        }
        if not args.server.startswith(("http://", "https://")) {
            raise ValueError("--server must start with http:// or https://");
        }
        url = args.server.rstrip("/") + "/api/planner/function/planner";
        request = Request(
            url,
            data=json.dumps({"action": action, "payload": payload}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        );
        with urlopen(request, timeout=10) as response {
            result = json.loads(response.read());
        }
        result = result.get("data", {}).get("result", result);
        if not result.get("ok", False) {
            print(
                "Planner: " + result.get("error", "Unexpected server response"),
                file=sys.stderr
            );
            return 2;
        }
        print(json.dumps(result, indent=2, ensure_ascii=False));
        return 0;
    } except HTTPError as e {
        print(
            "HTTP " + str(e.code) + " from " + args.server + ": " + e.read().decode(),
            file=sys.stderr
        );
        return 3;
    } except (URLError, TimeoutError, OSError) as e {
        print(
            "Cannot reach "
                + args.server
                + ": "
                + str(e)
                + ". Start `jac run` and check --server.",
            file=sys.stderr
        );
        return 3;
    } except ValueError as e {
        print("Invalid input: " + str(e), file=sys.stderr);
        return 2;
    }
}

with entry:__main__ {
    sys.`exit(main(sys.argv[1:]));
}
