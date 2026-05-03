from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({"message": "Hello, Flask!"})

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

@app.route("/users")
def users():
    # Dummy data (no DB)
    data = [
        {"id": 1, "name": "Richard", "email": "richard@example.com"},
        {"id": 2, "name": "Jane", "email": "jane@example.com"}
    ]
    return jsonify(data)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
