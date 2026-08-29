FROM node:22.8-bookworm

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone https://github.com/PrimeIntellect-ai/prime-agent.git .

RUN npm ci && npm run build

ENV PRIME_AGENT_CODING_AGENT_DIR=/app/data/config
ENV PRIME_AGENT_SESSION_DIR=/app/data/sessions

ENTRYPOINT ["/app/prime-agent.sh"]
