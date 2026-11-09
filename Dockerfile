FROM ctfd/ctfd:3.7.4
USER root
RUN pip install --no-cache-dir \
    "Flask-APScheduler==1.11.0" \
    "flask-redis==0.4.0" \
    "docker==4.1.0" \
    "redis==3.3.11" \
    "werkzeug<3.0.0" \
    "flask-restx>=1.3.0"
USER 1001
