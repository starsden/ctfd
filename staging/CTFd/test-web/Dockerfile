FROM nginx:alpine
COPY entrypoint.sh /entrypoint.sh
COPY index.html /usr/share/nginx/html/index.html
RUN chmod +x /entrypoint.sh
EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

