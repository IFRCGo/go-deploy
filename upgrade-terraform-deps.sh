#!/bin/bash

find . -name '.terraform.lock.hcl' -execdir terraform init -upgrade \;
