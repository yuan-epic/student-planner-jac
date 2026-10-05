"""Expo Go launcher for the pinned Jac 0.37.23 compiler.
Uses the same native compilation/staging functions as MobileTarget.dev,
without its unwanted second server / Android-build subprocess.
"""
import argparse;
import json;
import os;
import subprocess;
import sys;
import from pathlib { Path }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.client.targets.registry { target_for_kind }
import from jaclang.client.targets.react_native.build {
    stage_compiled_entry,
    stage_native_image_assets,
    entry_module_for,
    write_native_entry,
    strip_css_imports
}
import from jaclang.toolchains.javascript { build_environment }
import from jaclang.client.targets.react_native.common { resolve_node_tool }

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Compile Student Planner with Jac's native target, then run Expo Go. Restart this command after editing Jac sources."
    );
    parser.add_argument(
        "--check",
        action="store_true",
        help="Export the iOS JS bundle without starting Metro"
    );
    args = parser.parse_args(sys.argv[1:]);
    project = Path(__file__).resolve().parent.parent;
    entry_file = project / "mobile" / "main.jac";
    Jac.set_full_target_path(str(entry_file));
    target = target_for_kind("mobile", project);
    target.ensure_ready(project);
    builder: any = Jac.get_client_bundle_builder();
    compiler: any = builder._get_compiler().jac_client_compiler;
    compiler.compiled_dir.mkdir(parents=True, exist_ok=True);
    compiler.compile(None, entry_file, native=True);
    rn = project / ".jac" / "mobile-rn";
    strip_css_imports(compiler.compiled_dir);
    stage_compiled_entry(
        compiler.compiled_dir, rn, entry_module_for(entry_file, project)
    );
    stage_native_image_assets(rn / "jac-src", rn);
    write_native_entry(rn);
    config = json.loads((rn / "app.json").read_text());
    config["expo"]["name"] = "Student Planner";
    config["expo"]["slug"] = "student-planner";
    config["expo"]["ios"]["bundleIdentifier"] = "edu.studentplanner.lianjie";
    (rn / "app.json").write_text(json.dumps(config, indent=2) + "\n");
    command = resolve_node_tool(rn, "expo");
    if args.check {
        command += ["export", "--platform", "ios", "--output-dir", "ios-check"];
    } else {
        print(
            "Start `jac run` in another terminal. In the app, enter http://COMPUTER_LAN_IP:8000."
        );
        print(
            "Scan the Expo QR with iPhone Camera / Expo Go. No Mac or Android SDK is used."
        );
        command += ["start", "--go", "--lan", "--port", "8081", "--clear"];
    }
    try {
        sys.`exit(
            subprocess.call(
                command, cwd=str(rn), env=build_environment(dict(os.environ))
            )
        );
    } except KeyboardInterrupt {
        sys.`exit(0);
    }
}
