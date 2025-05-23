.PHONY: deps_table_update modified_only_fixup quality style fixup fix-copies test

# make sure to test the local checkout in scripts and not the pre-installed one (don't use quotes!)
export PYTHONPATH = src

modified_only_fixup:
	$(eval modified_py_files := $(shell python3 utils/get_modified_files.py $(check_dirs)))
	@if test -n "$(modified_py_files)"; then \
		echo "Checking/fixing $(modified_py_files)"; \
		black $(modified_py_files); \
		ruff check $(modified_py_files); \
	else \
		echo "No library .py files were modified"; \
	fi

# Update src/dependency_versions_table.py

deps_table_update:
	@python3 setup.py "deps_table_update"

deps_table_check_updated:
	@md5sum src/dependency_versions_table.py > md5sum.saved
	@python3 setup.py deps_table_update
	@md5sum -c --quiet md5sum.saved || (printf "\nError: the version dependency table is outdated.\nPlease run 'make fixup' or 'make style' and commit the changes.\n\n" && exit 1)
	@rm md5sum.saved

# autogenerating code

autogenerate_code: deps_table_update

# this target runs checks on all files

quality:
	python3 -m black --check $(check_dirs)
	python3 -m ruff check $(check_dirs)
# 	doc-builder style src docs/source --max_len 119 --check_only --path_to_docs docs/source


# this target runs checks on all files and potentially modifies some of them

style:
	python3 -m black .
	python3 -m ruff check . --fix

# Super fast fix and check target that only works on relevant modified files since the branch was made

fixup: modified_only_fixup autogenerate_code

# Make marked copies of snippets of codes conform to the original

fix-copies:
	python3 utils/check_copies.py --fix_and_overwrite
# 	python3 utils/check_dummies.py --fix_and_overwrite

# Run tests for the library

test:
	python3 -m pytest -n auto --dist=loadfile -s -v ./tests/


# Release stuff

pre-release:
	python3 utils/release.py

pre-patch:
	python3 utils/release.py --patch

post-release:
	python3 utils/release.py --post_release

post-patch:
	python3 utils/release.py --post_release --patch

# Docker
TAG ?= $(shell git rev-parse HEAD)
IMAGE = gitlab-master.nvidia.com:5005/sruhlingcach/video-diff-weather

image-build: ## Build the docker image: docker build -t gitlab-master.nvidia.com:5005/sruhlingcach/video-diff-weather:latest .
	docker build -t $(IMAGE):$(TAG)  environment/dockers/

image-enter: ## Enter the docker image
	docker run --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 --tty --interactive $(MOUNTS) $(IMAGE):$(TAG) bash

image-test: ## Test the docker image
	docker run  --rm -e WANDB_MODE=disabled --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 --tty --interactive $(MOUNTS)  $(IMAGE):$(TAG) bash -c "python -c 'import healpixpad' && pytest"

# make image-push
# will build the image, tag it with the git SHA, and push to gitlab
image-push: image-build ## push the docker image
	docker push $(IMAGE):$(TAG)

	
