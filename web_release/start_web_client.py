import http.server
import socketserver
import os
import sys

# Default Port
PORT = 8080

# Web Root Directory
if getattr(sys, 'frozen', False):
    # Running as compiled executable
    application_path = os.path.dirname(sys.executable)
else:
    # Running as script
    application_path = os.path.dirname(os.path.abspath(__file__))

WEB_DIR = os.path.join(application_path, 'www')

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        # Disable cache
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

try:
    print(f"Starting Web Server...")
    print(f"Root Directory: {WEB_DIR}")
    
    # Allow address reuse
    socketserver.TCPServer.allow_reuse_address = True
    
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"\n鉁?Web Server running at: http://localhost:{PORT}")
        print(f"   (Network IP: http://0.0.0.0:{PORT})")
        print("\nPress Ctrl+C to stop the server.")
        httpd.serve_forever()
except OSError as e:
    print(f"\n鉂?Error starting server on port {PORT}: {e}")
    print("Tip: The port might be in use. Try changing the PORT variable in this script.")
    input("Press Enter to exit...")
except KeyboardInterrupt:
    print("\nServer stopped.")
