# Use the official Python image as a base image
FROM python:3.9 AS builder

# Set the working directory inside the container
WORKDIR /app

# Install necessary dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application files into the container
COPY . /app

# Run the application
CMD ["python", "app.py"]