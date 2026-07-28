# Disposable Network GitOps Repository

This repository exists only inside the `automation` container. Its identified
initial commit contains baseline intent, inventory, validation fixtures, and the
pipeline engine. The student supplies the change intent, deterministic template,
and semantic tests before running a reviewed change.

The pipeline refuses to run unless the current directory is exactly
`/workspace/lab-repo` and that directory is this disposable Git repository.
