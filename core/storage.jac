import os;
import json;
import sqlite3;
import uuid;
import from pathlib { Path }
import from core.logic { validate }

def:priv connect() -> any {
    path = Path(
        os.environ.get(
            "STUDENT_PLANNER_DB",
            str(
                Path(__file__).resolve().parent.parent
                    / ".planner-data"
                    / "tasks.sqlite3"
            )
        )
    );
    path.parent.mkdir(parents=True, exist_ok=True);
    db = sqlite3.connect(str(path), timeout=10);
    db.execute(
        "CREATE TABLE IF NOT EXISTS tasks (id TEXT PRIMARY KEY, data TEXT NOT NULL)"
    );
    db.commit();
    return db;
}

def:priv read_tasks() -> list[dict[str, any]] {
    db = connect();
    try {
        return [
            json.loads(row[0])
            for row in db.execute("SELECT data FROM tasks").fetchall()
        ];
    } finally {
        db.close();
    }
}

def:priv mutate(action: str, payload: dict[str, any]) -> dict[str, any] {
    db = connect();
    try {
        db.execute("BEGIN IMMEDIATE");
        if action == "add" {
            task = validate(payload);
            task["id"] = str(uuid.uuid4());
            db.execute(
                "INSERT INTO tasks VALUES (?, ?)", (task["id"], json.dumps(task))
            );
        } else {
            task_id = payload.get("id", "");
            if not isinstance(task_id, str) or not task_id {
                raise ValueError("A task ID is required.");
            }
            row = db.execute(
                "SELECT data FROM tasks WHERE id = ?", (task_id, )
            ).fetchone();
            if row is None {
                raise ValueError("Task not found: " + task_id);
            }
            task = json.loads(row[0]);
            if action == "delete" {
                db.execute("DELETE FROM tasks WHERE id = ?", (task_id, ));
            } else {
                fields = {
                    k: v
                    for (k, v) in task.items()
                    if k != "id"
                };
                if action == "complete" {
                    if type(payload.get("completed")) is not bool {
                        raise ValueError("Completed must be true or false.");
                    }
                    fields["completed"] = payload["completed"];
                } else {
                    changes = payload.get("changes", {});
                    if not isinstance(changes, dict) or not changes {
                        raise ValueError("Provide task fields to update.");
                    }
                    fields.update(changes);
                }
                task = {** validate(fields), "id": task_id};
                db.execute(
                    "UPDATE tasks SET data = ? WHERE id = ?",
                    (json.dumps(task), task_id)
                );
            }
        }
        db.commit();
        return task;
    } except Exception {
        db.rollback();
        raise;
    } finally {
        db.close();
    }
}
