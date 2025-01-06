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


