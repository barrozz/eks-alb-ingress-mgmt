FROM python:3.9-slim

# COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
WORKDIR /app

COPY requirements.txt requirements.txt
RUN  pip install -r requirements.txt
COPY app.py .

CMD ["python", "app.py"]