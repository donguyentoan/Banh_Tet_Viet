# Build bản web Godot 4.3 rồi phục vụ bằng nginx (kèm proxy /api -> Vercel)
FROM barichello/godot-ci:4.3 AS build
WORKDIR /src
COPY . .
RUN mkdir -p build/web && godot --headless --import --path . || true
RUN godot --headless --path . --export-release "Web" build/web/index.html \
    && test -f build/web/index.wasm

FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 80
