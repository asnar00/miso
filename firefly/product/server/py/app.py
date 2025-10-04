from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/api/ping', methods=['GET'])
def ping():
    """Health check endpoint for connection monitoring"""
    return jsonify({
        'message': 'Firefly server is alive!',
        'status': 'ok'
    })

if __name__ == '__main__':
    # Run server on all interfaces, port 8080
    # Debug mode for development (auto-reload on code changes)
    app.run(host='0.0.0.0', port=8080, debug=True)
