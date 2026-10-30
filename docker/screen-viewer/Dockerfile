FROM python:3.14.6-alpine3.23@sha256:b165067c5afc37fa5608a3c05609cc3d51aafd808a30fbfd822ee594fef55ad4
WORKDIR /opt/libki-viewer
COPY requirements.txt .
RUN pip install --no-cache-dir --no-deps --require-hashes --only-binary=:all: -r requirements.txt
COPY libki_token_plugin.py run_gateway.py ./
RUN mkdir -p /var/lib/libki-viewer/nonces && chown -R 65534:65534 /var/lib/libki-viewer
ENV LIBKI_VIEWER_NONCE_DIR=/var/lib/libki-viewer/nonces
ENV PYTHONPATH=/opt/libki-viewer PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
USER 65534:65534
EXPOSE 6080
CMD ["python", "run_gateway.py", "--token-plugin=libki_token_plugin.LibkiTokenPlugin", "--token-source=/run/secrets/libki_viewer_hmac", "--heartbeat=30", "0.0.0.0:6080"]
