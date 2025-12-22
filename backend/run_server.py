import uvicorn
import os
import sys

# Ensure proper path for imports when running as exe
if getattr(sys, 'frozen', False):
    # When frozen, PyInstaller sets sys._MEIPASS as the temp directory.
    # We don't need to append 'backend' to path because 'backend' package
    # should be available in the root of the bundle (or PYZ).
    # If anything, we might need to ensure sys._MEIPASS is in path (it usually is).
    pass
else:
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.main import app

if __name__ == "__main__":
    # Use 127.0.0.1 for local access
    uvicorn.run(app, host="127.0.0.1", port=8000)
