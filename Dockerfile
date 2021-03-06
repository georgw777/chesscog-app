# Rather messy Dockerfile for deployment with heroku. 
# To stay on the free tier, the backend and the frontend need to be crammed into one Docker container.

# Build environment
FROM node:15.2.0 AS app_build
WORKDIR /app
ENV PATH /app/node_modules/.bin:$PATH

COPY app/package-lock.json app/package.json app/tsconfig.json ./
RUN npm install

COPY app/public/ public/
COPY app/src/ src/
COPY app/.env .env
RUN npm run build

# Production environment
FROM tiangolo/uvicorn-gunicorn-fastapi:python3.8

# Set environment variables
ENV MAX_WORKERS 1
ENV WEB_CONCURRENCY 1
ENV PORT 3000

# Install dependencies
RUN apt update && apt install -y nginx libgl1-mesa-glx

# Install poetry
RUN pip install --upgrade pip && \
    pip install poetry && \
    poetry config virtualenvs.create false

# Install backend dependencies
COPY ./api/pyproject.toml ./api/poetry.lock* /app/
RUN poetry install --no-root --no-dev

# Download models
RUN poetry run python -m chesscog.occupancy_classifier.download_model && \
    poetry run python -m chesscog.piece_classifier.download_model

# Setup frontend
COPY --from=app_build /app/build /usr/share/nginx/html
COPY app/docker/heroku_nginx_template.conf nginx_template.conf

# Copy the backend
COPY ./api/app /app

# Entrypoint
CMD cp nginx_template.conf /etc/nginx/nginx.conf && \
    sed -i "s/_PORT_/$PORT/g" /etc/nginx/nginx.conf && \
    nginx -g 'daemon off;' & \
    PORT=3000 /start.sh