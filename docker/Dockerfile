# OpenWrt 25.12 Buildhost fuer Bintec RS353 (lantiq/xrx200)
# Quellbaum liegt im named volume /build, NICHT im Windows-Bind-Mount
# (Windows-FS ist case-insensitive -> OpenWrt-Buildbaum bricht).
FROM debian:bookworm-20260918-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

ENV DEBIAN_FRONTEND=noninteractive

# python3-distutils optional wie PKGS_OPTIONAL in build_rs353_linux.sh
# (fehlt ab Python 3.12); Fehlschlag bricht den Build nicht ab.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential clang flex bison g++ gawk \
        gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
        python3 python3-dev python3-setuptools \
        rsync unzip zlib1g-dev file wget swig time ca-certificates \
        libelf-dev ecj fastjar java-propose-classpath \
        java-wrappers jq quilt xsltproc zstd less nano procps \
    && { apt-get install -y --no-install-recommends python3-distutils || true; } \
    && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} build && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash build && \
    mkdir -p /build && chown build:build /build

USER build
WORKDIR /build

CMD ["/bin/bash"]
