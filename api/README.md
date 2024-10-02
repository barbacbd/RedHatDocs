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