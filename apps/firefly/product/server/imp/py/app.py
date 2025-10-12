from flask import Flask, render_template_string, jsonify, request
import os
import signal

app = Flask(__name__)

# HTML template with the noob logo
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Firefly Server</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background-color: #40E0D0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        .logo {
            font-size: 120px;
            color: black;
            text-align: center;
        }
        .status {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: rgba(0,0,0,0.1);
            padding: 10px 20px;
            border-radius: 5px;
            font-size: 14px;
            color: black;
        }
    </style>
</head>
<body>
    <div class="logo">ᕦ(ツ)ᕤ</div>
    <div class="status">Firefly Server Running</div>
</body>
</html>
'''

@app.route('/')
def index():
    """Serve the main page with the noob logo"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/ping', methods=['GET'])
def ping():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'message': 'Firefly server is running'
    })

@app.route('/api/shutdown', methods=['POST'])
def shutdown():
    """Shutdown the server remotely"""
    # Send SIGTERM to the process
    os.kill(os.getpid(), signal.SIGTERM)
    return jsonify({
        'status': 'shutting down',
        'message': 'Server is shutting down'
    })

if __name__ == '__main__':
    # Run on all interfaces so it's accessible from network
    # Port 8080 as specified
    print("Starting Firefly server on http://0.0.0.0:8080")
    print(f"Local IP: http://192.168.1.76:8080")
    print(f"Public IP: http://185.96.221.52:8080")
    app.run(host='0.0.0.0', port=8080, debug=False)
