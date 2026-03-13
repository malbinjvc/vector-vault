FROM ruby:3.3-slim AS builder
WORKDIR /app
COPY Gemfile ./
RUN bundle install --jobs 4

FROM ruby:3.3-slim
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app appuser
WORKDIR /app
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .
RUN chown -R appuser:appgroup /app
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ruby -e "require 'net/http'; Net::HTTP.get(URI('http://localhost:8080/health'))" || exit 1
CMD ["ruby", "app.rb"]
