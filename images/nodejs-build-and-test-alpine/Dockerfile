FROM node:lts-alpine

# Mettre a jour les packages Alpine
RUN apk update
RUN apk upgrade

# Installer les outils de d?veloppement n?cessaires
RUN apk add --no-cache python3 make g++

RUN apk add --no-cache chromium \
&& apk add --no-cache bash

ENV CHROME_BIN /usr/bin/chromium-browser

RUN npm install -g @angular/cli

RUN adduser -h /home/test -s /bin/bash -u 12311 -D test

RUN ln -s /usr/local/bin/npm /usr/bin/npm
RUN ln -s /usr/local/bin/ng /usr/bin/ng

