import from core.logic { ZONE, clock_now, select_tasks, recommend }
import from core.storage { read_tasks, mutate }

"""The only public planning endpoint. Every client uses this same authority."""
def:pub planner(action: str, payload: dict[str, any]) -> dict[str, any] {
    try {
        now = clock_now();
        if action in ["add", "edit", "delete", "complete"] {
            return {"ok": True, "task": mutate(action, payload)};
        }
        tasks = read_tasks();
        if action == "list" {
            return {
                "ok": True,
                "tasks": select_tasks(tasks, payload, now),
                "timezone": ZONE,
                "today": now.strftime("%Y-%m-%d"),
                "server_time": now.isoformat(),
                "stats": {
                    "total": len(tasks),
                    "completed": len(
                        [
                            t
                            for t in tasks
                            if t["completed"]
                        ]
                    ),
                    "open": len(
                        [
                            t
                            for t in tasks
                            if not t["completed"]
                        ]
                    )
                }
            };
        }
        if action == "plan" {
            return {"ok": True, ** recommend(tasks, payload.get("budget", 0), now)};
        }
        raise ValueError(
            "Unknown action. Use add, list, edit, complete, delete or plan."
        );
    } except ValueError as e {
        return {"ok": False, "error": str(e)};
    }
}
