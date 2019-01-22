# This is for building production images. Development environment gems are not installed.

# Before building image, copy logo file to app/assets/images/ and gpgkeyimport.txt to main directory.

# It is not efficient to use rails:onbuild image because every change to the app's source code will mean
# every step in this Dockerfile needs to run again. This is because the ONBUILD commands are run
# before anything in the Dockerfile.
FROM ruby:2.5

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN groupadd rails && useradd --create-home -g rails rails
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y gnupg --no-install-recommends && rm -rf /var/lib/apt/lists/*
#RUN apt-get update && apt-get install -y nodejs --no-install-recommends && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y mysql-client postgresql-client sqlite3 --no-install-recommends && rm -rf /var/lib/apt/lists/*

COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
RUN bundle install --without development test

COPY . /usr/src/app
# The config option in development.rb means 'listen' gem is required and "rake assets:precompile" won't run when that gem is missing.
# Removing that line prevents the dependence on 'listen' gem when running commands in non-production environment.
# Other workaround is to run rake with RAILS_ENV=production SECRET_KEY_BASE=anything env.
RUN sed -i '/ActiveSupport::EventedFileUpdateChecker/d' config/environments/development.rb
RUN chown -R rails:rails /usr/src/app

# CVE-2016–3714
COPY imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

USER rails
RUN mkdir -p tmp/pids
RUN gpg --import gpgkeyimport.txt
RUN echo "personal-digest-preferences SHA512 SHA384 SHA256\nno-emit-version" > ~/.gnupg/gpg.conf
# this is for use in prod instances but doesn't hurt having them in dev.
RUN bundle exec rake assets:precompile

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
