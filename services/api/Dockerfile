FROM python:3.12-slim
WORKDIR /app
COPY pyproject.toml ./
COPY eatme ./eatme
RUN pip install --no-cache-dir . && useradd --uid 10001 --create-home eatme && mkdir /data && chown eatme /data
USER 10001
EXPOSE 8000
CMD ["uvicorn", "eatme.api:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
