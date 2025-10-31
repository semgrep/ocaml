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
    opam clean --download-cache --repo-cache --all-switches && \
    rm -rf /home/semgrep/.opam/5.3.0/.opam-switch/sources

# TODO: How will it know where to get our sources in the future? Will it ever need to download them again?

#Override the default command to launch a login shell
CMD ["/bin/sh", "-l"]
