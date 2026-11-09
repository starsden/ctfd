FROM ctfd/ctfd:3.7.4

USER root

# Зависимости плагина whale с фиксацией werkzeug<3.0.0 для предотвращения конфликта с flask_restx
RUN pip install --no-cache-dir \
    "Flask-APScheduler==1.11.0" \
    "flask-redis==0.4.0" \
    "docker==4.1.0" \
    "redis==3.3.11" \
    "werkzeug<3.0.0" \
    "flask-restx>=1.3.0"

# Плагин ctfd-whale (исходники в staging/CTFd/whale)
COPY whale/ /opt/CTFd/CTFd/plugins/ctfd-whale/

USER 1000
