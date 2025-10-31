#docker build -t semgrep/ocaml-5.3.0-semgrep .
FROM alpine:3.22

# Ash won't source the profile by default
SHELL ["/bin/sh", "-l", "-c"]

# Install OPAM and dependencies
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache opam build-base git bash && \
    rm -rf /var/cache/apk/*

RUN addgroup -S semgrep && adduser -S semgrep -G semgrep
USER semgrep

# OCaml setup with our own compiler and toolchain + dev packages for IDEs
RUN --mount=type=bind,target=/home/semgrep/repo \
    opam init --bare --disable-sandboxing --auto-setup -v && \
    opam update && \
    opam switch create 5.3.0 --empty -y -v && \
    echo 'eval $(opam env --switch=5.3.0)' >> /home/semgrep/.profile && \
    eval $(opam env --switch=5.3.0) && \
    opam pin add ocaml-variants.5.3.0 "/home/semgrep/repo" --update-invariant -y && \
    opam install lsp dune ocaml-lsp-server utop odoc ocamlformat -y && \
    opam clean --download-cache --repo-cache --all-switches

#Override the default command to launch a login shell
CMD ["/bin/sh", "-l"]
