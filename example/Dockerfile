# syntax=docker/dockerfile:1
# Conformance example app (Dream). Build with the package folder as the
# context:  docker build -f example/Dockerfile .
FROM ocaml/opam:debian-ocaml-5.2 AS build
ENV OPAMYES=1 OPAMCONFIRMLEVEL=unsafe-yes
RUN sudo apt-get update -qq && sudo apt-get install -y -qq libev-dev libssl-dev libgmp-dev pkg-config >/dev/null
# The packages from this repo's own source, not from the opam repository.
COPY --chown=opam dune-project dune privatus-analytics.opam privatus-analytics-dream.opam LICENSE README.md CHANGELOG.md /home/opam/pkg/
COPY --chown=opam src/ /home/opam/pkg/src/
RUN opam pin add -n privatus-analytics /home/opam/pkg && \
    opam pin add -n privatus-analytics-dream /home/opam/pkg && \
    opam install privatus-analytics-dream >/dev/null
COPY --chown=opam example/ /home/opam/example/
WORKDIR /home/opam/example
RUN opam exec -- dune build --root . ./app.exe && cp _build/default/app.exe /home/opam/app.exe

FROM debian:13-slim
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends libev4 libssl3t64 libgmp10 ca-certificates >/dev/null && rm -rf /var/lib/apt/lists/*
COPY --from=build /home/opam/app.exe /usr/local/bin/privatus-example
EXPOSE 8080
USER 65534
CMD ["privatus-example"]
