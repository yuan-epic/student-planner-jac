import from core.service { planner }
import "./style.css";

def:pub app -> JsxElement {
    has tasks: list[dict[str, any]] = [],
        stats: dict[str, any] = {"total": 0, "completed": 0, "open": 0},
        view: str = "today",
        category: str = "all",
        status: str = "all",
        today: str = "",
        busy: bool = False,
        error: str = "",
        notice: str = "",
        editing: str = "",
        show_form: bool = False,
        title: str = "",
        task_category: str = "Coursework",
        due_date: str = "",
        due_time: str = "",
        priority: str = "Medium",
        minutes: str = "30",
        notes: str = "",
        budget: str = "120",
        plan: any = None;

    async def refresh {
        busy = True;
        error = "";
        try {
            result = await planner(
                "list", {"view": view, "category": category, "status": status}
            );
            if not result["ok"] {
                error = result["error"];
            } else {
                tasks = result["tasks"];
                stats = result["stats"];
                today = result["today"];
            }
        } except Error as e {
            error = "Cannot reach the planner. Check the server and retry. "
                + String(e);
        } finally {
            busy = False;
        }
    }
    async can with [view, category, status] entry {
        await refresh();
    }

    def open_form(task: any) {
        editing = task["id"] if task else "";
        title = task["title"] if task else "";
        task_category = task["category"] if task else "Coursework";
        due_date = task["due_date"] if task else today;
        due_time = task["due_time"] if task else "";
        priority = task["priority"] if task else "Medium";
        minutes = String(task["minutes"]) if task else "30";
        notes = task["notes"] if task else "";
        error = "";
        show_form = True;
    }
    async def save(event: any) {
        event.preventDefault();
        busy = True;
        error = "";
        notice = "";
        payload = {
            "title": title,
            "category": task_category,
            "due_date": due_date,
            "due_time": due_time,
            "priority": priority,
            "minutes": Number(minutes),
            "notes": notes
        };
        try {
            result = await planner(
                "edit" if editing else "add",
                {"id": editing, "changes": payload} if editing else payload
            );
            if not result["ok"] {
                error = result["error"];
            } else {
                show_form = False;
                plan = None;
                notice = "Task saved.";
                await refresh();
            }
        } except Error as e {
            error = "Save failed. " + String(e);
        } finally {
            busy = False;
        }
    }
    async def change(task: any, action: str) {
        if action == "delete"
            and not window.confirm(
                "Delete '" + task["title"] + "'? This cannot be undone."
            ) {
            return;
        }
        busy = True;
        error = "";
        try {
            result = await planner(
                action, {"id": task["id"], "completed": not task["completed"]}
            );
            if not result["ok"] {
                error = result["error"];
            } else {
                plan = None;
                notice = "Task deleted." if action == "delete" else "Task updated.";
                await refresh();
            }
        } except Error as e {
            error = "Update failed. " + String(e);
        } finally {
            busy = False;
        }
    }
    async def make_plan(event: any) {
        event.preventDefault();
        busy = True;
        error = "";
        try {
            result = await planner("plan", {"budget": Number(budget)});
            if result["ok"] {
                plan = result;
            } else {
                error = result["error"];
            }
        } except Error as e {
            error = "Planning failed. " + String(e);
        } finally {
            busy = False;
        }
    }
    return
        <div className="shell">
            <aside>
                <a className="brand" href="/">
                    SP
                    <span>Student Planner</span>
                </a>
                <p className="eyebrow">YOUR SPACE TO FOCUS</p>
                <nav aria-label="Task views">
                    {[
                        <button
                            key={item[0]}
                            className={"nav " + ("active" if view == item[0] else "")}
                            disabled={busy}
                            onClick={lambda { view = item[0]; }}
                        >
                            {item[1]}
                        </button>
                        for item in [
                            ["today", "Today"],
                            ["week", "Next 7 Days"],
                            ["overdue", "Overdue"],
                            ["all", "All Tasks"]
                        ]
                    ]}
                </nav>
                <div className="side-note">
                    One plan. Every screen.
                    <p>Web · Mobile · CLI</p>
                    <small>America/New_York</small>
                </div>
            </aside>
            <main>
                <header>
                    <div>
                        <p className="eyebrow">A LITTLE STRUCTURE. A CLEARER DAY.</p>
                        <h1>
                            {"Today"
                                if view == "today"
                                else "Next 7 Days"
                                    if view == "week"
                                    else "Overdue"
                                        if view == "overdue"
                                        else "All Tasks"}
                        </h1>
                        <p className="muted">{today} · America/New_York</p>
                    </div>
                    <button
                        className="primary"
                        disabled={busy}
                        onClick={lambda { open_form(None); }}
                    >
                        + New task
                    </button>
                </header>
                <section className="stats" aria-label="Overall progress">
                    <div>
                        <strong>{stats["open"]}</strong>
                        <span>Tasks to go</span>
                    </div>
                    <div>
                        <strong>{stats["completed"]}</strong>
                        <span>Completed</span>
                    </div>
                    <div>
                        <strong>{stats["total"]}</strong>
                        <span>Total tasks</span>
                        <progress value={stats["completed"]} max={stats["total"] or 1}/>
                    </div>
                </section>
                {<div role="alert" className="error">
                    {error}
                    <button disabled={busy} onClick={refresh}>Retry refresh</button>
                </div>
                    if error
                    else None}
                <p role="status" className="muted">
                    {("Loading…" if busy else notice)}
                </p>
                <section className="workspace">
                    <div>
                        <div className="toolbar">
                            <label>
                                Category
                                <select
                                    value={category}
                                    disabled={busy}
                                    onChange={lambda (e: any) { category = e.target.value; }}
                                >
                                    {[
                                        <option key={c} value={c}>
                                            {"All categories" if c == "all" else c}
                                        </option>
                                        for c in [
                                            "all",
                                            "Coursework",
                                            "Research",
                                            "Applications",
                                            "Personal"
                                        ]
                                    ]}
                                </select>
                            </label>
                            <label>
                                Status
                                <select
                                    value={status}
                                    disabled={busy}
                                    onChange={lambda (e: any) { status = e.target.value; }}
                                >
                                    <option value="all">All statuses</option>
                                    <option value="open">Open</option>
                                    <option value="completed">Completed</option>
                                </select>
                            </label>
                            <button disabled={busy} onClick={refresh}>Refresh</button>
                        </div>
                        <div className="task-list" aria-busy={busy}>
                            {[
                                <article
                                    className={"task "
                                        + ("done" if task["completed"] else "")}
                                    key={task["id"]}
                                >
                                    <div className="task-heading">
                                        <button
                                            className="check"
                                            disabled={busy}
                                            aria-label={(
                                                "Restore "
                                                    if task["completed"]
                                                    else "Complete "
                                            )
                                                + task["title"]}
                                            onClick={lambda { change(
                                                task, "complete"
                                            ); }}
                                        >
                                            {"✓" if task["completed"] else "○"}
                                        </button>
                                        <div>
                                            <span className="tag">
                                                {task["category"]}
                                            </span>
                                            <h2>{task["title"]}</h2>
                                        </div>
                                        <span
                                            className={"priority " + task["priority"]}
                                        >
                                            {task["priority"]}
                                        </span>
                                    </div>
                                    <p
                                        className={"details "
                                            + ("late" if task["overdue"] else "")}
                                    >
                                        {task["due_date"]} {task["due_time"]
                                            or "· all day"} · {task["minutes"]} min {"· Overdue"
                                            if task["overdue"]
                                            else ""}
                                    </p>
                                    {<p className="notes">{task["notes"]}</p>
                                        if task["notes"]
                                        else None}
                                    <footer>
                                        <small>ID: {task["id"]}</small>
                                        <button
                                            disabled={busy}
                                            onClick={lambda { open_form(task); }}
                                        >
                                            Edit
                                        </button>
                                        <button
                                            className="danger"
                                            disabled={busy}
                                            onClick={lambda { change(task, "delete"); }}
                                        >
                                            Delete
                                        </button>
                                    </footer>
                                </article> for task in tasks
                            ]}
                        </div>
                        {<div className="empty">
                            <h2>A little breathing room.</h2>
                            <p>
                                No tasks match this view. Add a task or change the filters.
                            </p>
                        </div>
                            if not busy and len(tasks) == 0
                            else None}
                    </div>
                    <section className="plan">
                        <p className="eyebrow">MAKE TIME FOR PROGRESS</p>
                        <h2>Your study plan</h2>
                        <p>How many minutes can you set aside today?</p>
                        <form onSubmit={make_plan}>
                            <label>
                                Available minutes
                                <input
                                    type="number"
                                    min="1"
                                    max="1440"
                                    step="1"
                                    required={True}
                                    value={budget}
                                    onChange={lambda (e: any) { budget = e.target.value; }}
                                />
                            </label>
                            <button className="primary" disabled={busy}>
                                Build my plan
                            </button>
                        </form>
                        <small>
                            Uses all open tasks, independent of the current filters. Earliest deadlines first; no API key needed.
                        </small>
                        {<div>
                            <h3>
                                {plan["total_minutes"]} / {plan[
                                    "budget"
                                ]} minutes planned
                            </h3>
                            <ol>
                                {[
                                    <li key={t["id"]}>
                                        <strong>{t["title"]}</strong>{" "}
                                        ·{" "}
                                        {t["minutes"]}{" "}
                                        min
                                        <p>{t["reason"]}</p>
                                    </li> for t in plan["tasks"]
                                ]}
                            </ol>
                            {<p>No whole task fits this budget.</p>
                                if len(plan["tasks"]) == 0
                                else None}
                            <h3>Not scheduled ({len(plan["unscheduled"])})</h3>
                            {[
                                <p key={t["id"]}>
                                    <strong>{t["title"]}</strong>
                                    <br/>
                                    {t["reason"]}
                                </p> for t in plan["unscheduled"]
                            ]}
                            <small>{plan["method"]}</small>
                        </div>
                            if plan
                            else None}
                    </section>
                </section>
                <footer className="credit">
                    Student Planner · Lianjie Yuan · Built with Jac
                </footer>
            </main>
            {<div className="overlay">
                <section
                    role="dialog"
                    aria-modal="true"
                    aria-labelledby="form-title"
                    className="modal"
                >
                    <h2 id="form-title">
                        {"Edit task" if editing else "A new step forward"}
                    </h2>
                    <p className="muted">Dates and times use America/New_York.</p>
                    {<p role="alert" className="error">{error}</p> if error else None}
                    <form onSubmit={save}>
                        <label>
                            Title
                            <input
                                autoFocus={True}
                                required={True}
                                maxLength={200}
                                value={title}
                                onChange={lambda (e: any) { title = e.target.value; }}
                            />
                        </label>
                        <div className="form-grid">
                            <label>
                                Category
                                <select
                                    value={task_category}
                                    onChange={lambda (e: any) { task_category = e.target.value; }}
                                >
                                    {[
                                        <option key={c}>{c}</option>
                                        for c in [
                                            "Coursework",
                                            "Research",
                                            "Applications",
                                            "Personal"
                                        ]
                                    ]}
                                </select>
                            </label>
                            <label>
                                Priority
                                <select
                                    value={priority}
                                    onChange={lambda (e: any) { priority = e.target.value; }}
                                >
                                    {[
                                        <option key={p}>{p}</option>
                                        for p in ["High", "Medium", "Low"]
                                    ]}
                                </select>
                            </label>
                            <label>
                                Due date
                                <input
                                    type="date"
                                    required={True}
                                    value={due_date}
                                    onChange={lambda (e: any) { due_date = e.target.value; }}
                                />
                            </label>
                            <label>
                                Time (optional)
                                <input
                                    type="time"
                                    value={due_time}
                                    onChange={lambda (e: any) { due_time = e.target.value; }}
                                />
                            </label>
                        </div>
                        <label>
                            Estimated minutes
                            <input
                                type="number"
                                min="1"
                                max="10080"
                                step="1"
                                required={True}
                                value={minutes}
                                onChange={lambda (e: any) { minutes = e.target.value; }}
                            />
                        </label>
                        <label>
                            Notes (optional)
                            <textarea
                                maxLength={4000}
                                value={notes}
                                onChange={lambda (e: any) { notes = e.target.value; }}
                            />
                        </label>
                        <div className="actions">
                            <button
                                type="button"
                                disabled={busy}
                                onClick={lambda { show_form = False; }}
                            >
                                Cancel
                            </button>
                            <button className="primary" disabled={busy}>
                                {"Saving…" if busy else "Save task"}
                            </button>
                        </div>
                    </form>
                </section>
            </div>
                if show_form
                else None}
        </div>;
}
