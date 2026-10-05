import from core.logic { validate, select_tasks, recommend, overdue }
import from core.storage { mutate, read_tasks }
import from datetime { datetime }
import from zoneinfo { ZoneInfo }
import tempfile;
import os;


def task(id: str = "a", due: str = "2026-10-03", minutes: int = 30) -> dict[str, any] {
    return {
        "id": id,
        "title": "Test task",
        "category": "Coursework",
        "due_date": due,
        "due_time": "",
        "priority": "Medium",
        "minutes": minutes,
        "completed": False,
        "notes": ""
    };
}

def now(value: str) -> any {
    return datetime.fromisoformat(value).astimezone(ZoneInfo("America/New_York"));
}

test "date_boundaries_and_status" {
    rows = [
        task("y", "2026-10-02"),
        task("t"),
        task("6", "2026-10-09"),
        task("7", "2026-10-10")
    ];
    instant = now("2026-10-03T00:00:00-04:00");
    assert [t["id"] for t in select_tasks(rows, {"view": "today"}, instant)] == ["t"];
    assert [t["id"] for t in select_tasks(rows, {"view": "week"}, instant)]
        == ["t", "6"];
    assert [t["id"] for t in select_tasks(rows, {"view": "overdue"}, instant)] == ["y"];
    assert not overdue(task(), now("2026-10-03T23:59:59-04:00"));
    assert overdue(task(), now("2026-10-04T00:00:00-04:00"));
    rows[0]["completed"] = True;
    assert select_tasks(rows, {"view": "overdue"}, instant) == [];
    assert len(select_tasks(rows, {"status": "completed"}, instant)) == 1;
    assert len(select_tasks(rows, {"category": "Research"}, instant)) == 0;
}

test "timezone_and_dst" {
    assert len(
        select_tasks([task()], {"view": "today"}, now("2026-10-04T03:59:59+00:00"))
    )
        == 1;
    assert len(
        select_tasks([task()], {"view": "today"}, now("2026-10-04T04:00:00+00:00"))
    )
        == 0;
    timed = task();
    timed["due_time"] = "12:00";
    assert not overdue(timed, now("2026-10-03T12:00:00-04:00"));
    assert overdue(timed, now("2026-10-03T12:00:01-04:00"));
    ambiguous = task(due="2026-11-01");
    ambiguous["due_time"] = "01:30";
    assert not overdue(ambiguous, now("2026-11-01T05:30:00+00:00"));
    assert overdue(ambiguous, now("2026-11-01T06:00:00+00:00"));
    invalid = {
        k: v
        for (k, v) in task(due="2026-03-08").items()
        if k != "id"
    };
    invalid["due_time"] = "02:30";
    raised = False;
    try {
        validate(invalid);
    } except ValueError {
        raised = True;
    }
    assert raised;
}

test "input_validation" {
    base = {
        k: v
        for (k, v) in task().items()
        if k != "id"
    };
    for changes in [
        {"title": "  "},
        {"minutes": 0},
        {"minutes": True},
        {"minutes": 1.5},
        {"minutes": "20"},
        {"due_date": "2026-02-30"},
        {"due_time": "24:00"},
        {"category": "Other"},
        {"completed": "false"},
        {"priority": "Urgent"},
        {"injected": 1}
    ] {
        raised = False;
        try {
            validate({** base, ** changes});
        } except ValueError {
            raised = True;
        }
        assert raised;
    }
    assert validate({** base, "title": "  Read paper  "})["title"] == "Read paper";
}

test "budget_greedy_skips_oversized_and_completed" {
    rows = [
        task("large", "2026-10-01", 100),
        task("a", minutes=20),
        task("b", minutes=30),
        task("done", minutes=1)
    ];
    rows[3]["completed"] = True;
    instant = now("2026-10-03T12:00:00-04:00");
    plan = recommend(rows, 50, instant);
    assert plan["total_minutes"] == 50;
    assert [t["id"] for t in plan["tasks"]] == ["a", "b"];
    assert [t["id"] for t in plan["unscheduled"]] == ["large"];
    for budget in range(1, 151) {
        result = recommend(rows, budget, instant);
        assert result["total_minutes"] <= budget;
        assert sum([t["minutes"] for t in result["tasks"]]) == result["total_minutes"];
    }
    high = task("high", minutes=20);
    high["priority"] = "High";
    assert recommend([task("low", minutes=20), high], 20, instant)["tasks"][0]["id"]
        == "high";
    for budget in [0, -1, 1441, True] {
        raised = False;
        try {
            recommend(rows, budget, instant);
        } except ValueError {
            raised = True;
        }
        assert raised;
    }
}

test "persistence_mutations_and_atomic_invalid_update" {
    old = os.environ.get("STUDENT_PLANNER_DB");
    with tempfile.TemporaryDirectory() as folder {
        os.environ["STUDENT_PLANNER_DB"] = folder + "/tasks.sqlite3";
        try {
            fields = {
                k: v
                for (k, v) in task().items()
                if k != "id"
            };
            made = mutate("add", fields);
            id = made["id"];
            assert len(id) == 36;
            assert read_tasks()[0]["title"] == "Test task";
            mutate(
                "edit", {"id": id, "changes": {"title": "Edited", "notes": "A note"}}
            );
            mutate("complete", {"id": id, "completed": True});
            assert read_tasks()[0]["completed"];
            mutate("complete", {"id": id, "completed": False});
            try {
                mutate("edit", {"id": id, "changes": {"title": "Bad", "minutes": -1}});
            } except ValueError {}
            assert read_tasks()[0]["title"] == "Edited";
            assert not read_tasks()[0]["completed"];
            mutate("delete", {"id": id});
            assert read_tasks() == [];
            raised = False;
            try {
                mutate("delete", {"id": id});
            } except ValueError {
                raised = True;
            }
            assert raised;
        } finally {
            if old is None {
                del os.environ["STUDENT_PLANNER_DB"];
            } else {
                os.environ["STUDENT_PLANNER_DB"] = old;
            }
        }
    }
}
