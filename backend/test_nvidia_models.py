import os
import requests
import json

api_key = os.environ.get("NVIDIA_API_KEY", "")

url = "https://integrate.api.nvidia.com/v1/models"
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

try:
    response = requests.get(url, headers=headers)
    models = response.json().get('data', [])
    for m in models:
        if 'meta' in m['id']:
            print(m['id'])
except Exception as e:
    print(f"Error: {e}")
