import re;
import from datetime { datetime, timedelta, timezone }
import from zoneinfo { ZoneInfo }

glob ZONE: str = "America/New_York";

def:priv clock_now() -> any {
    return datetime.now(ZoneInfo(ZONE));
}

def:priv validate(data: dict[str, any]) -> dict[str, any] {
    allowed = {
        "title",
        "category",
        "due_date",
        "due_time",
        "priority",
        "minutes",
        "notes",
        "completed"
    };
    if set(data.keys()) - allowed {
        raise ValueError("Unknown task field.");
    }
    for field in ["title", "category", "due_date", "priority", "minutes"] {
        if field not in data {
            raise ValueError("Missing field: " + field);
        }
    }
    for field in ["title", "category", "due_date", "priority", "due_time", "notes"] {
        if not isinstance(data.get(field, ""), str) {
            raise ValueError(field + " must be text.");
        }
    }
    title = data["title"].strip();
    if not title or len(title) > 200 {
        raise ValueError("Title must contain 1–200 characters.");
    }
    if data["category"] not in ["Coursework", "Research", "Applications", "Personal"] {
        raise ValueError("Choose Coursework, Research, Applications or Personal.");
    }
    if data["priority"] not in ["High", "Medium", "Low"] {
        raise ValueError("Choose High, Medium or Low priority.");
    }
    if type(data["minutes"]) is not int
        or data["minutes"] < 1
        or data["minutes"] > 10080 {
        raise ValueError("Estimated minutes must be an integer from 1 to 10080.");
    }
    if type(data.get("completed", False)) is not bool {
        raise ValueError("Completed must be true or false.");
    }
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", data["due_date"]) {
        raise ValueError("Due date must be YYYY-MM-DD.");
    }
    try {
        datetime.strptime(data["due_date"], "%Y-%m-%d");
    } except ValueError {
        raise ValueError("Due date is not a valid calendar date.");
    }
    due_time = data.get("due_time", "");
    if due_time and not re.fullmatch(r"([01]\d|2[0-3]):[0-5]\d", due_time) {
        raise ValueError("Optional time must be HH:MM (24-hour New York time).");
    }
    if len(data.get("notes", "")) > 4000 {
        raise ValueError("Notes must be at most 4000 characters.");
    }
    cleaned = {
        "title": title,
        "category": data["category"],
        "due_date": data["due_date"],
        "due_time": due_time,
        "priority": data["priority"],
        "minutes": data["minutes"],
        "notes": data.get("notes", ""),
        "completed": data.get("completed", False)
    };
    if due_time {
        local = datetime.strptime(data["due_date"] + " " + due_time, "%Y-%m-%d %H:%M");
        aware = local.replace(tzinfo=ZoneInfo(ZONE), fold=0);
        if aware.astimezone(timezone.utc).astimezone(ZoneInfo(ZONE)).replace(
            tzinfo=None
        )
            != local {
            raise ValueError(
                "This New York time does not exist because daylight saving time starts. Choose another time."
            );
        }
    }
    return cleaned;
}

def:priv overdue(task: dict[str, any], now: any) -> bool {
    if task["completed"] {
        return False;
    }
    today = now.strftime("%Y-%m-%d");
    if not task["due_time"] {
        return task["due_date"] < today;
    }
    deadline = datetime.strptime(
        task["due_date"] + " " + task["due_time"], "%Y-%m-%d %H:%M"
    ).replace(
        tzinfo=ZoneInfo(ZONE), fold=0
    );
    return deadline.astimezone(timezone.utc) < now.astimezone(timezone.utc);
}

def:priv ordering(task: dict[str, any]) -> tuple[str, str, int, int, str] {
    return (
        task["due_date"],
        task["due_time"] or "23:59:59",
        {"High": 0, "Medium": 1, "Low": 2}[task["priority"]],
        task["minutes"],
        task["id"]
    );
}

def:priv select_tasks(
    tasks: list[dict[str, any]], filters: dict[str, any], now: any
) -> list[dict[str, any]] {
    view = filters.get("view", "all");
    category = filters.get("category", "all");
    status = filters.get("status", "all");
    if view not in ["all", "today", "week", "overdue"] {
        raise ValueError("View must be all, today, week or overdue.");
    }
    if category not in ["all", "Coursework", "Research", "Applications", "Personal"] {
        raise ValueError("Invalid category filter.");
    }
    if status not in ["all", "open", "completed"] {
        raise ValueError("Status must be all, open or completed.");
    }
    today = now.strftime("%Y-%m-%d");
    end = (now + timedelta(days=7)).strftime("%Y-%m-%d");
    result = [];
    for task in tasks {
        if category != "all" and task["category"] != category {
            continue;
        }
        if status == "open" and task["completed"] {
            continue;
        }
        if status == "completed" and not task["completed"] {
            continue;
        }
        if view == "today" and task["due_date"] != today {
            continue;
        }
        if view == "week" and not (today <= task["due_date"] < end) {
            continue;
        }
        if view == "overdue" and not overdue(task, now) {
            continue;
        }
        result.append({** task, "overdue": overdue(task, now)});
    }
    return sorted(result, key=ordering);
}

def:priv recommend(
    tasks: list[dict[str, any]], budget: int, now: any
) -> dict[str, any] {
    if type(budget) is not int or budget < 1 or budget > 1440 {
        raise ValueError("Budget must be an integer from 1 to 1440 minutes.");
    }
    candidates = sorted(
        [
            t
            for t in tasks
            if not t["completed"]
        ],
        key=ordering
    );
    chosen = [];
    skipped = [];
    used = 0;
    for task in candidates {
        if used + task["minutes"] <= budget {
            reason = "Overdue" if overdue(task, now) else "Due " + task["due_date"];
            chosen.append(
                {
                    ** task,
                    "reason": reason
                        + "; "
                        + task["priority"].lower()
                        + " priority; fits the remaining budget."
                }
            );
            used += task["minutes"];
        } else {
            skipped.append(
                {
                    ** task,
                    "reason": "Needs "
                        + str(task["minutes"])
                        + " minutes; only "
                        + str(budget - used)
                        + " remain at this point."
                }
            );
        }
    }
    return {
        "tasks": chosen,
        "unscheduled": skipped,
        "total_minutes": used,
        "budget": budget,
        "remaining_minutes": budget - used,
        "method": "Earliest deadline first; priority breaks deadline ties, then shorter tasks. Whole tasks only; oversized tasks are skipped."
    };
}
