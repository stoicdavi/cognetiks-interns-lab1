
# Use a lightweight official Python image
FROM python:3.10-slim

# Set the working directory inside the container
WORKDIR /app

# Copy dependency file and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application source code into the container
COPY app ./app

# Expose the port the app will run on
EXPOSE 8001

# Launch the FastAPI/ASGI app with Uvicorn
# Use JSON array form so the shell doesn't interpret args
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
