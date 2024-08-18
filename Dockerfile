FROM node:18-alpine as build-stage

WORKDIR /app/frontend

COPY frontend/package*.json ./

RUN npm install

COPY frontend/ .

RUN npm run build

FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y debootstrap xorriso genisoimage grub-pc-bin grub-efi-amd64-bin \
    curl nodejs npm sudo linux-image-generic mtools isolinux syslinux-utils squashfs-tools && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install

COPY --from=build-stage /app/frontend/dist ./dist

RUN chmod -R 755 /usr/src/app/dist

COPY . .

RUN chmod +x create_iso.sh

RUN mkdir -p /usr/src/app/isos

EXPOSE 3000

CMD ["node", "server.js"]
