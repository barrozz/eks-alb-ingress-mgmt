from flask import Flask, jsonify
import requests
import time
from datetime import datetime


app = Flask(__name__)

# Define the API endpoint for fetching Bitcoin value
BITCOIN_API_ENDPOINT = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd'

def get_bitcoin_value(service_name):
    try:
        # Make a request to the specified Bitcoin API endpoint
        response = requests.get(BITCOIN_API_ENDPOINT)
        response.raise_for_status()

        # Extract the Bitcoin value from the response
        bitcoin_value = response.json()['bitcoin']['usd']

        # Get the current timestamp rounded to minutes
        timestamp = datetime.utcnow().strftime('%y-%m-%d %H:%M UTC')

        return f'Service {service_name}, bitcoin value is {bitcoin_value}$ for \'{timestamp}\''
    except requests.exceptions.RequestException as e:
        print(f'Error fetching Bitcoin value: {e}')
        return jsonify({'error': 'Error fetching Bitcoin value'})


@app.route('/ServiceB')
def service_b():
    return get_bitcoin_value('B')

if __name__ == '__main__':
    # Run the Flask app on all available network interfaces for local testing
    app.run(host='0.0.0.0', port=5000)
