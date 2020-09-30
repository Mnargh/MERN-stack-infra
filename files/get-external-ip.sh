#!/bin/bash
set -eu

# see: https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/data_source
jq -n --arg IP "$(curl -sSL http://ifconfig.io)" '{"ip": $IP}'
