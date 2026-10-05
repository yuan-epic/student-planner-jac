# Submission preparation

1. Replace `YOUR_UMID` in root README.
2. Complete and record the iPhone acceptance checklist in `VALIDATION.md`.
3. Export a new directory using `python3 planner_tools/export.py /tmp/student-planner-submission`.
4. Review its contents; run the README commands there. The directory must be new.
5. Create your own GitHub repository and add **that exported directory's files**.
   Do not run `git add .` in the unrelated robotics workspace.
6. Confirm the repository opens for the course staff; submit its link to Canvas.

Suggested local commit sequence, from the exported directory:

```bash
git init
git add README.md jac.toml .gitignore core web mobile cli planner_tests planner_tools planner_docs
git diff --cached --stat
git commit -m "feat: add Jac Student Planner with shared web, mobile and CLI workflows"
```

GitHub remote setup/push and Canvas submission are your separate actions.
No remote URL has been assumed and no credentials are included. The implementation
session did not initialize, commit, push, deploy or submit on your behalf.

The assignment includes an acknowledged version-specific native launch adapter.
The app source remains entirely Jac; Python files only export source and run
integration tests. No generated JS, binaries, SQLite data, personal tasks,
virtualenvs or `node_modules` belong in the submission.
