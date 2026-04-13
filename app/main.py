from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'environment': os.getenv('ENVIRONMENT', 'unknown'),
        'version': os.getenv('APP_VERSION', '1.0.0')
    })

@app.route('/')
def home():
    return jsonify({
        'message': 'Welcome to Python CI/CD Pipeline',
        'environment': os.getenv('ENVIRONMENT', 'unknown')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
