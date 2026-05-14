#!/bin/bash
set -euo pipefail

convertlcov() {
  local LCOV_FILE=$1
  
  local lf=0
  local lh=0

  while IFS= read -r line; do
    if [[ $line == "LF:"* ]]; then
      ((lf+=${line#LF:}))
    elif [[ $line == "LH:"* ]]; then
      ((lh+=${line#LH:}))
    fi
  done < "$LCOV_FILE"

  echo "Lines_covered: $lh"
  echo "Lines_total: $lf"
  echo "Coverage: $((lh * 100 / lf))%"
}

convertlcov "$@"
