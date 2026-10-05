import from "@jac/mobui" { View, Text, TextInput, Pressable, ScrollView, StyleSheet }
import from core.remote { remote_call }

glob styles = StyleSheet.create(
         {
             screen: {flex: 1, backgroundColor: "#f6f7f2"},
             body: {padding: 24, paddingTop: 62, paddingBottom: 50, gap: 14},
             title: {fontSize: 30, fontWeight: "bold", color: "#164e44"},
             heading: {fontSize: 18, fontWeight: "bold", color: "#233a34"},
             text: {fontSize: 14, color: "#53685d", lineHeight: 21},
             card: {
                 padding: 18,
                 borderWidth: 1,
                 borderColor: "#dce3d7",
                 borderRadius: 14,
                 backgroundColor: "white",
                 gap: 10
             },
             input: {
                 padding: 12,
                 borderWidth: 1,
                 borderColor: "#ccd7cf",
                 borderRadius: 8,
                 backgroundColor: "white",
                 color: "#233a34"
             },
             button: {
                 padding: 13,
                 backgroundColor: "#205c4c",
                 borderRadius: 9,
                 alignItems: "center"
             },
             buttonText: {color: "white", fontWeight: "bold"},
             row: {flexDirection: "row", flexWrap: "wrap", gap: 8},
             chip: {
                 padding: 10,
                 borderWidth: 1,
                 borderColor: "#bbcdbb",
                 borderRadius: 9
             },
             selected: {backgroundColor: "#dbe8d3"},
             error: {
                 padding: 14,
                 backgroundColor: "#ffeadd",
                 borderRadius: 9,
                 color: "#943d26"
             }
         }
     );

def:pub app -> JsxElement {
    has server: str = "http://127.0.0.1:8000",
        connected: str = "",
        tasks: list[dict[str, any]] = [],
        view: str = "today",
        busy: bool = False,
        error: str = "",
        today: str = "",
        notice: str = "",
        title: str = "",
        due: str = "",
        minutes: str = "30",
        category: str = "Coursework",
        priority: str = "Medium";
    async def refresh {
        busy = True;
        error = "";
        try {
            result = await remote_call(server.strip(), "list", {"view": view});
            tasks = result["tasks"];
            today = result["today"];
            connected = server.strip();
            if not due {
                due = result["today"];
            }
        } except Error as e {
            error = "Could not load tasks. Check the backend URL and Wi-Fi, then refresh. "
                + String(e);
        } finally {
            busy = False;
        }
    }
    async can with [view] entry {
        if connected {
            await refresh();
        }
    }
    async def add {
        busy = True;
        error = "";
        notice = "";
        try {
            await remote_call(
                server.strip(),
                "add",
                {
                    "title": title,
                    "category": category,
                    "due_date": due,
                    "priority": priority,
                    "minutes": Number(minutes),
                    "due_time": "",
                    "notes": ""
                }
            );
            title = "";
            notice = "Task added. Refresh All Tasks if it is not due today.";
            await refresh();
        } except Error as e {
            error = "Could not add task. " + String(e);
        } finally {
            busy = False;
        }
    }
    async def toggle(task: any) {
        busy = True;
        error = "";
        try {
            await remote_call(
                server.strip(),
                "complete",
                {"id": task["id"], "completed": not task["completed"]}
            );
            notice = "Task updated on the shared server.";
            await refresh();
        } except Error as e {
            error = "Could not update task. " + String(e);
        } finally {
            busy = False;
        }
    }
    return
        <ScrollView
            style={styles.screen}
            contentContainerStyle={styles.body}
            keyboardShouldPersistTaps="handled"
        >
            <Text style={styles.title}>Student Planner</Text>
            <Text style={styles.text}>Make room for what matters.</Text>
            <View style={styles.card}>
                <Text style={styles.heading}>Shared backend</Text>
                <Text style={styles.text}>
                    On iPhone, replace 127.0.0.1 with your computer's LAN IP. Start jac run on the computer first.
                </Text>
                <TextInput
                    accessibilityLabel="Backend URL"
                    style={styles.input}
                    value={server}
                    autoCapitalize="none"
                    autoCorrect={False}
                    onChangeText={lambda (t: str) {
                        server = t;
                        connected = "";
                        tasks = [];
                    }}
                />
                <Pressable style={styles.button} disabled={busy} onPress={refresh}>
                    <Text style={styles.buttonText}>
                        {"Loading…" if busy else "Connect / Refresh"}
                    </Text>
                </Pressable>
                <Text style={styles.text}>
                    {("Connected: " + connected + " · " + today)
                        if connected
                        else "Not connected"}
                </Text>
                <Text style={styles.text}>All dates: America/New_York</Text>
            </View>
            {<Text accessibilityRole="alert" style={styles.error}>{error}</Text>
                if error
                else <View/>}
            {<Text style={styles.text}>{notice}</Text> if notice else <View/>}
            <View style={styles.row}>
                {[
                    <Pressable
                        key={v[0]}
                        disabled={busy}
                        style={[styles.chip, styles.selected if view == v[0] else {}]}
                        onPress={lambda { view = v[0]; }}
                    >
                        <Text>{v[1]}</Text>
                    </Pressable> for v in [["today", "Today"], ["all", "All Tasks"]]
                ]}
            </View>
            {<Text style={styles.text}>No tasks in this view.</Text>
                if connected and not busy and len(tasks) == 0
                else <View/>}
            {[
                <View style={styles.card} key={task["id"]}>
                    <Text style={styles.heading}>
                        {("✓ " if task["completed"] else "") + task["title"]}
                    </Text>
                    <Text style={styles.text}>
                        {task["category"]} · {task["priority"]} · {task["minutes"]} min
                    </Text>
                    <Text style={styles.text}>
                        {task["due_date"]} {task["due_time"] or "· all day"} {"· Overdue"
                            if task["overdue"]
                            else ""}
                    </Text>
                    <Text style={styles.text}>ID: {task["id"]}</Text>
                    <Pressable
                        style={styles.button}
                        disabled={busy or not connected}
                        onPress={lambda { toggle(task); }}
                    >
                        <Text style={styles.buttonText}>
                            {"Restore task" if task["completed"] else "Complete task"}
                        </Text>
                    </Pressable>
                </View> for task in tasks
            ]}
            <View style={styles.card}>
                <Text style={styles.heading}>Quick add</Text>
                <TextInput
                    style={styles.input}
                    accessibilityLabel="Task title"
                    placeholder="Task title"
                    value={title}
                    maxLength={200}
                    onChangeText={lambda (t: str) { title = t; }}
                />
                <Text style={styles.text}>Category</Text>
                <View style={styles.row}>
                    {[
                        <Pressable
                            key={c}
                            style={[
                                styles.chip,
                                styles.selected if category == c else {}
                            ]}
                            onPress={lambda { category = c; }}
                        >
                            <Text>{c}</Text>
                        </Pressable>
                        for c in ["Coursework", "Research", "Applications", "Personal"]
                    ]}
                </View>
                <Text style={styles.text}>Priority</Text>
                <View style={styles.row}>
                    {[
                        <Pressable
                            key={p}
                            style={[
                                styles.chip,
                                styles.selected if priority == p else {}
                            ]}
                            onPress={lambda { priority = p; }}
                        >
                            <Text>{p}</Text>
                        </Pressable> for p in ["High", "Medium", "Low"]
                    ]}
                </View>
                <Text style={styles.text}>Due date (YYYY-MM-DD)</Text>
                <TextInput
                    accessibilityLabel="Due date"
                    style={styles.input}
                    value={due}
                    placeholder="YYYY-MM-DD"
                    onChangeText={lambda (t: str) { due = t; }}
                />
                <Text style={styles.text}>Estimated minutes</Text>
                <TextInput
                    accessibilityLabel="Estimated minutes"
                    style={styles.input}
                    value={minutes}
                    keyboardType="number-pad"
                    onChangeText={lambda (t: str) { minutes = t; }}
                />
                <Pressable
                    style={styles.button}
                    disabled={busy or not connected}
                    onPress={add}
                >
                    <Text style={styles.buttonText}>Add task</Text>
                </Pressable>
            </View>
            <Text style={styles.text}>
                Lianjie Yuan · Built with Jac + React Native
            </Text>
        </ScrollView>;
}
