from flask import Flask, render_template
from flask_socketio import SocketIO
import requests
import json
import threading
from datetime import datetime, timedelta

app = Flask(__name__)
socketio = SocketIO(app)

bitcoin_values = []
average_values = []


def fetch_bitcoin_value():
    while True:
        try:
            response = requests.get(
                "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"
            )
            data = response.json()
            bitcoin_value = data.get("bitcoin", {}).get("usd")

            if bitcoin_value is not None:
                timestamp = datetime.utcnow().strftime("%y-%m-%d %H:%M UTC")
                result = f"Service A, bitcoin value is {bitcoin_value:.2f}$ for '{timestamp}'"

                bitcoin_values.append(result)
                socketio.emit("bitcoin_value", {"data": result}, namespace="/serviceA")

                if len(bitcoin_values) % 10 == 0:
                    average = sum(
                        float(value.split(" ")[5].replace("$", "").replace("'", ""))
                        for value in bitcoin_values[-10:]
                    ) / 10
                    average_result = f"Service A, average bitcoin value for the last 10 minutes is {average:.2f}$"
                    average_values.append(average_result)
                    socketio.emit(
                        "average_value", {"data": average_result}, namespace="/serviceA"
                    )

        except Exception as e:
            print(f"Error fetching bitcoin value: {e}")

        # Fetch every minute
        socketio.sleep(60)


@app.route("/ServiceA")
def index():
    return render_template("index.html")


@socketio.on("connect", namespace="/serviceA")
def handle_connect():
    print("Client connected")


@socketio.on("disconnect", namespace="/serviceA")
def handle_disconnect():
    print("Client disconnected")


if __name__ == "__main__":
    # bitcoin_thread = threading.Thread(target=fetch_bitcoin_value)
    # bitcoin_thread.daemon = True
    # bitcoin_thread.start()

    socketio.start_background_task(fetch_bitcoin_value)
    socketio.run(app, host='0.0.0.0', port=5000, debug=True, allow_unsafe_werkzeug=True)
