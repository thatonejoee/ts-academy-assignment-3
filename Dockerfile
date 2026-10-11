# Lightweight base image (about 8 MB)
FROM alpine:3.20

LABEL org.opencontainers.image.title="devops-tool" \
      org.opencontainers.image.description="Bash CLI built and tested by a GitHub Actions pipeline"

# Install only what the app needs:
#   bash       - the app uses Bash features ([[ ]], /dev/tcp)
#   musl-utils - provides getent for hostname resolution
RUN apk add --no-cache bash musl-utils

# Run as an unprivileged user instead of root.
RUN adduser -D -u 10001 appuser

WORKDIR /app

# Copy only the application, then make it executable.
COPY app/ /app/
RUN chmod 0755 /app/*.sh

USER appuser

# ENTRYPOINT is the program; CMD is the default argument.
#   docker run devops-tool            -> app.sh help
#   docker run devops-tool system-info
ENTRYPOINT ["/app/app.sh"]
CMD ["help"]
