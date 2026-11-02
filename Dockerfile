FROM ctfd/ctfd:latest
USER root
RUN pip install --no-cache-dir \
    Flask-APScheduler==1.11.0 \
    docker==4.1.0 \
    flask-redis==0.4.0 \
    redis==3.3.11
USER 1001
