# API



# Notes

1. API requires GOPATH to be set for protobuf file generation.

```
export GOPATH=/path/to/go
```

Add api to the src directory

```
cd /path/to/go  # this is your GOPATH above
# alternatively you could cd $GOPATH

# these can be done in one step with -p to make the parent dirs
mkdir github.com && cd github.com
mkdir openshift && cd openshift
```

Now that you have the structure setup, you can clone api here. 


2. OSX requires some help to run some of the make commands.

The user should edit `udpate-protobuf.sh` file to change the `libprotoc` value to match the value that is on their computer. Dealing with `brew` can be a headache, so it may be easier to temporarily change this.

**Note: this could introduce unforseen errors, or it could miss errors. (When possible use the correct version).**

3. When running the verify script(s) you must not have any outstanding code or the `git diff` will cause a failure.


## Adding tests

The tests must be added after the CRDs are created (using `make update`) for your feature. 

In this example we edited the `config/v1/types_infrastructure.go` file. This is the `infrastructures.config.openshift.io` CRD. We will use this for the test. The new tests should go in the directory/tests where files were edited. In this case `config/v1/tests`. 

Add the initial data to the top of the file for the tests

```yaml
apiVersion: apiextensions.k8s.io/v1 # Hack because controller-gen complains if we don't have this
name: "Infrastructure"
crdName: infrastructures.config.openshift.io   <<<< this will change based on the CRD created/edit
featureGates:
- Name of the Feature Gate                     <<<< This will change based on the tested feature or feature gate
```

Next we need to add the tests. The test below is very simple. It should not error as it is just a basic setup.

```yaml
tests:
  onCreate:
    - name: Should be able to create a minimal Infrastructure
      initial: |
        apiVersion: config.openshift.io/v1
        kind: Infrastructure
        spec: {} # No spec is required for a Infrastructure
      expected: |
        apiVersion: config.openshift.io/v1
        kind: Infrastructure
        spec: {}

```

### Failures

Use the yaml tag `expectedError` for Spec or general errors, and use the tag `expectedStatusError` for status errors.


### Running single tests

If you want to run specific tests go to the Makefile in the directory where your tests will be located. Continuing with the example above lets look at `config/v1/Makefile`.

We need to adjust the `test` tag. The `GINKGO_EXTRA_ARGS` args can be adjusted to search for specific tests. 

```bash
.PHONY: test
test:
	make -C ../../tests test GINKGO_EXTRA_ARGS=--focus="SpecificTestName"
```

In order to run the tests for a specific location 

```bash
make -C config/v1 test
```

where the `config/v1` is the location where there the tests are located (in a test directory). Change this value in order to change the tests that are executed.
