FROM postgres:17

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        postgresql-server-dev-17 && \
    rm -rf /var/lib/apt/lists/*

# Uncomment to build and install pgvector.
# RUN cd /tmp && \
#     git clone --branch v0.8.2 https://github.com/pgvector/pgvector.git && \
#     cd pgvector && \
#     make OPTFLAGS="" && \
#     make install && \
#     rm -rf /tmp/pgvector
