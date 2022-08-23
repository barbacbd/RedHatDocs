# Review Guidelines

The purpose of this document is to provide information to assist in the peer review process.


## Review Process

1. First glance at the code through the github PR information.
2. Check docs:
- If a bug, check the bz/jira bug docs
- If a task, check the jira card docs
3. Run local tests
4. Detailed code examination.
- Formulate questions/concerns
- Formulate/Suggest fixes


### Things to look for

1. Misspellings in strings
2. Unused/Reused Variables
3. Newer/Safer functions from external APIs
4. Unncessarily complicated code blocks
5. Incorrectly formatted strings
6. Incorrectly formatted errors


## Documentation


1. If a step in a procedure is to run a command, add "run/enter the following command". The [following page](https://github.com/openshift/openshift-docs/blob/main/contributing_to_docs/doc_guidelines.adoc#code-blocks-command-syntax-and-example-output) provides several examples.





# Rebasing

`git pull --rebase <upstream> master`