FROM searxng/searxng:latest

# Install Caddy for Host header rewriting (the OpenHost router strips Host
# and sets X-Forwarded-Host; SearXNG needs them to match for correct URLs)
RUN apk add --no-cache caddy

# Copy our startup wrapper and Caddyfile
COPY start.sh /app/start.sh
COPY Caddyfile /app/Caddyfile
RUN chmod +x /app/start.sh

EXPOSE 3000

ENTRYPOINT []
CMD ["/app/start.sh"]
