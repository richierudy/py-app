FROM python:3.11-slim

WORKDIR /app

# Copy requirements first for better caching
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ .

# Non-root user for security
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \\
    CMD python -c "import requests; requests.get('http://localhost:8080/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "main:app"]
