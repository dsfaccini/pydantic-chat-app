# Multi-stage build for optimized production image
FROM python:3.13-slim AS builder

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install system dependencies needed for building
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install uv for faster Python package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Copy ONLY dependency files for better layer caching
COPY pyproject.toml uv.lock ./

# Install dependencies (production only)
RUN --mount=type=cache,id=s/4e1a817a-3929-4aad-9c90-d2900a4ab497-/root/.cache/uv,target=/root/.cache/uv \
    uv sync --frozen --no-dev


# Production stage - minimal runtime image
FROM python:3.13-slim AS runtime

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:$PATH" \
    UV_NO_CACHE=1

WORKDIR /app

# Create non-root user for security with home directory
RUN groupadd -r appuser && useradd -r -g appuser -m -d /home/appuser appuser

# Copy uv from builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Copy virtual environment from builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy ONLY necessary application files (not .env, not tests, etc.)
COPY chat_app.py chat_app.html chat_app.ts favicon.ico ./

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Railway automatically sets PORT env variable
ENV PORT=${PORT:-8080}

# Expose the port
EXPOSE $PORT

# Run the application
CMD ["python", "chat_app.py"]
