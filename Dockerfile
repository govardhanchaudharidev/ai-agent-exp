FROM node:22-alpine

WORKDIR /workspace

# Install the Pi coding agent at build time so this container runs offline
# after the first build. --ignore-scripts disables dependency lifecycle
# scripts per Pi's official install recommendation.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

ENTRYPOINT ["tail", "-f", "/dev/null"]
