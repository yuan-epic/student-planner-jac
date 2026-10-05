import from react { useState }

# Client-only HTTP adapter, shared by the native screen and its web preview.
# It never opens a database. The URL always names the already-running web server.
async def:pub remote_call(base: str, action: str, payload: dict[str, any]) -> any {
    if not base.startswith("http://") and not base.startswith("https://") {
        raise Error(
            "Enter the computer's backend URL, starting with http:// or https://."
        );
    }
    controller = new(AbortController);
    timer = setTimeout(lambda { controller.abort(); }, 10000);
    try {
        response = await fetch(
            base.rstrip("/") + "/api/planner/function/planner",
            {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": JSON.stringify({"action": action, "payload": payload}),
                "signal": controller.signal
            }
        );
        if not response.ok {
            raise Error("Backend HTTP " + String(response.status));
        }
        envelope = await response.json();
        result = envelope["data"]["result"] if envelope["data"] else envelope;
        if not result["ok"] {
            raise Error(result["error"] or "Unexpected server response");
        }
        return result;
    } finally {
        clearTimeout(timer);
    }
}
