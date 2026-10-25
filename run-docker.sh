#!/bin/sh
# Builds, tests, checks formatting, builds the docs and lints the opam files
# in the official OCaml image. Installed opam packages are kept in the named
# volume privatus-ocaml-opam, so later runs are fast. Usage: ./run-docker.sh
set -e
IMAGE="${IMAGE:-ocaml/opam:debian-ocaml-5.2}"
docker run --rm -v "$PWD":/src -v privatus-ocaml-opam:/home/opam/.opam -w /src \
  -e DUNE_BUILD_DIR=/tmp/_build -e OPAMYES=1 -e OPAMCONFIRMLEVEL=unsafe-yes "$IMAGE" sh -c 'set -e
  sudo apt-get update -qq >/dev/null
  sudo apt-get install -y -qq libev-dev libssl-dev libgmp-dev pkg-config >/dev/null 2>&1
  dune build ./privatus-analytics.opam ./privatus-analytics-dream.opam
  opam install --deps-only --with-test --with-doc ./privatus-analytics.opam ./privatus-analytics-dream.opam >/dev/null
  opam install tyxml ocamlformat.0.29.0 >/dev/null
  echo "== build"; dune build -p privatus-analytics,privatus-analytics-dream @install
  echo "== format"; dune build @fmt
  echo "== tests"; dune runtest --force
  echo "== docs"; dune build @doc
  echo "== opam lint"; opam lint privatus-analytics.opam privatus-analytics-dream.opam
  rm -f ./*.install
'
