# Enhancements

In order to test the changes made to enhancements run `make lint`


On OSX this may cause issues with `buildx` if you are using `docker`. In the event that an error similar to:

```
"buildx requires 1 argument":
```
**Note: you _may_ not be using buildx explicitly.**

This error usually means you are missing the build context (the . at the end of the command) or the image tag (-t option). To solve this temporarily,
open the `Makefile` and find the section causing the issue (ex: `image`). Add the directory to the end of the command:

```
image:  ## Build local container image
	$(RUNTIME) image build -f ./hack/Dockerfile.markdownlint --tag enhancements-markdownlint:latest
```

becomes the following (notice the directory added to the end of the command). 

```
image:  ## Build local container image
	$(RUNTIME) image build -f ./hack/Dockerfile.markdownlint --tag enhancements-markdownlint:latest ./hack
```
