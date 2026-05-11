#!/usr/bin/env python3
"""Run the game server from the project root."""
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

if __name__ == "__main__":
    import uvicorn
    from server.config import config
    uvicorn.run(
        "server.main:app",
        host=config.HOST,
        port=config.PORT,
        reload=True,
    )
