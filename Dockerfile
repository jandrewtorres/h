# Stage 1: Build static frontend assets.
FROM node:16-alpine@sha256:2ca257ee86a65e8d7fe6bb0ed3df2e7336b7c5a1662512627c99428beed8bdae as build

ENV NODE_ENV production

# Install dependencies.
WORKDIR /tmp/frontend-build
COPY package-lock.json ./
COPY package.json ./
RUN npm ci --production
RUN npm install --global gulp-cli@2.3.0

# Build h js/css.
COPY gulpfile.js ./
COPY scripts/gulp ./scripts/gulp
COPY h/static ./h/static
RUN npm run build

# Stage 2: Build the rest of the app using the build output from Stage 1.
FROM python:3.8.9-alpine3.13@sha256:e5bb2c97a121cbc773d56b55e744e2e67450bd9c1ea6b5c93af77061e745daea
LABEL maintainer="Hypothes.is Project and contributors"

# Install system build and runtime dependencies.
RUN apk add --no-cache \
    libffi \
    libpq \
    nginx \
    git

# Create the hypothesis user, group, home directory and package directory.
RUN addgroup -S hypothesis && adduser -S -G hypothesis -h /var/lib/hypothesis hypothesis
WORKDIR /var/lib/hypothesis

# Ensure nginx state and log directories writeable by unprivileged user.
RUN chown -R hypothesis:hypothesis /var/log/nginx /var/lib/nginx

# Copy nginx config
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Copy minimal data to allow installation of dependencies.
COPY requirements/requirements.txt ./

# Install build deps, build, and then clean up.
RUN apk add --no-cache --virtual build-deps \
    build-base \
    libffi-dev \
    postgresql-dev \
  && pip install --no-cache-dir -U pip \
  && pip install --no-cache-dir -r requirements.txt \
  && apk del build-deps

# Copy frontend assets.
COPY --from=build /tmp/frontend-build/build build

# Copy the rest of the application files.
COPY . .

# If we're building from a git clone, ensure that .git is writeable
RUN [ -d .git ] && chown -R hypothesis:hypothesis .git || :

# Expose the default port.
EXPOSE 5000

# Set the application environment
ENV PATH /var/lib/hypothesis/bin:$PATH
ENV PYTHONIOENCODING utf_8
ENV PYTHONPATH /var/lib/hypothesis:$PYTHONPATH

# Start the web server by default
USER hypothesis
CMD ["init-env", "supervisord", "-c" , "conf/supervisord.conf"]
