#!/bin/bash

# Find all directories containing .terraform.lock.hcl
for dir in $(find . -name '.terraform.lock.hcl' -exec dirname {} \; | sort -u); do
  echo "▶️ Upgrading Terraform in directory: $dir"
  (
    cd "$dir" || continue
    terraform init -upgrade
  )
done
