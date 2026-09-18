# Digest-pinned: the v0.0.7 tag is mutable and carries models_data/ and database/.
FROM francecosta/nerve:v0.0.7@sha256:f49feae627370f12bde8a4ec12a117b53e5840caf10a21531e7fc1e9c46fd9f9 AS final

ARG NERVE_COMMIT=unknown
LABEL org.opencontainers.image.source="https://github.com/nerve-bio/NERVE" \
      org.opencontainers.image.revision="${NERVE_COMMIT}"

# Inherited value has an empty component, which puts the CWD on sys.path.
ENV PYTHONPATH="/usr/nerve_python/NERVE:/usr/nerve_python"

# COPY overlays rather than mirrors; drops files deleted upstream and stale .pyc.
RUN rm -rf /usr/nerve_python/NERVE/code
COPY ./code /usr/nerve_python/NERVE/code
# Refuse to build without the normalizer.
RUN grep -q normalize_header /usr/nerve_python/NERVE/code/Quality_control.py
WORKDIR /workdir
EXPOSE 8880
RUN chmod +x /usr/nerve_python/NERVE/code/NERVE.py

ENTRYPOINT ["/usr/nerve_python/NERVE/code/NERVE.py"]
