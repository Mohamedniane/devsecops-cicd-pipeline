from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "message": "PFE DevSecOps API",
        "version": "1.0.0",
        "status": "running"
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/info')
def info():
    return jsonify({
        "app": "pfe-devsecops",
        "environment": "staging",
        "security": "DevSecOps pipeline active"
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)

