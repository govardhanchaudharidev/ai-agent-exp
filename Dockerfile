FROM node:22-alpine

WORKDIR /workspace

# Install DSH at build time — this container runs offline after
RUN npm install -g @deepseek-ai/dsh

ENTRYPOINT ["tail", "-f", "/dev/null"]
