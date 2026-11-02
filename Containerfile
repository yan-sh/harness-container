FROM node:22-bookworm-slim

ARG HARNESS

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates curl git gosu util-linux xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN case "$HARNESS" in \
      claude) npm install -g @anthropic-ai/claude-code ;; \
      codex) npm install -g @openai/codex ;; \
      opencode) npm install -g @opencode/cli ;; \
      pi) npm install -g --ignore-scripts @earendil-works/pi-coding-agent ;; \
      *) echo "Unknown harness: $HARNESS" >&2; exit 2 ;; \
    esac

RUN userdel node && groupdel node \
    && useradd -m -d /home/agent agent \
    && mkdir -p /home/agent/.config /home/agent/.local/share \
    && chown -R agent:agent /home/agent

COPY container/entrypoint.sh /usr/local/bin/harness-entrypoint
COPY container/launch.sh /usr/local/bin/harness-launch
COPY container/run-in-nix.sh /usr/local/bin/harness-run-in-nix
RUN chmod 755 /usr/local/bin/harness-entrypoint /usr/local/bin/harness-launch /usr/local/bin/harness-run-in-nix

ENV HOME=/home/agent
ENV USER=agent LOGNAME=agent DISABLE_UPDATES=1
WORKDIR /home/agent
ENTRYPOINT ["/usr/local/bin/harness-entrypoint"]
