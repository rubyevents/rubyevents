ARG RUBY_VERSION=4.0.1
FROM docker.io/library/ruby:$RUBY_VERSION-slim

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    imagemagick \
    libjemalloc2 \
    libvips \
    libyaml-dev \
    node-gyp \
    pkg-config \
    python-is-python3 \
    sqlite3 \
    chromium chromium-driver \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy all application code
COPY . .

# Install JavaScript dependencies
ARG NODE_VERSION=22.15.1
ARG YARN_VERSION=1.22.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Setup dependencies
RUN bin/setup --skip-server

# Default command
CMD ["bin/dev"]
