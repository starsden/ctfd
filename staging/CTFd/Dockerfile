FROM ctfd/ctfd:3.7.4

USER root

# Зависимости плагина whale
RUN pip install --no-cache-dir \
    Flask-APScheduler \
    flask-redis \
    docker \
    redis \
    Flask-Caching

# Плагин ctfd-whale (исходники в staging/CTFd/whale)
COPY whale/ /opt/CTFd/CTFd/plugins/ctfd-whale/

USER 1000
