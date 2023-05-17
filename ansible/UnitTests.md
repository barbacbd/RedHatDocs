# Executing Ansible Tests

Create a virtual environment for `python3.9` or greater.

```bash
python3.9 -m venv venv
```

Activate the environment.

```bash
source venv/bin/activate
```

Run the tests locally

```bash
bin/ansible-test {test-type} --docker -v {module}
```

- `test-type` - unit, sanity, integration
- `module` - module that should be tested (can be left blank)