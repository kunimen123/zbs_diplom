FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY . .
RUN flutter clean
RUN flutter pub get
RUN flutter build web --release

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]