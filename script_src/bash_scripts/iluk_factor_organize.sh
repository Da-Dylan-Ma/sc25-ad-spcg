#!/bin/bash

for l_file in *L_factor*.mtx; do
  u_file="${l_file/L_factor/U_factor}"

  if [ -f "$u_file" ]; then
    dir_name="${l_file/L_factor/}"
    dir_name="${dir_name/U_factor/}"
    dir_name="${dir_name%.mtx}"

    mkdir -p "$dir_name"

    mv "$l_file" "$dir_name/"
    mv "$u_file" "$dir_name/"
  fi
done
