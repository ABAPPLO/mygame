import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routes import ai_routes, game_routes
from .config import config

logging.basicConfig(level=logging.INFO)

app = FastAPI(title="AI Hero Chronicle - Game Server", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(ai_routes.router, prefix="/api")
app.include_router(game_routes.router, prefix="/api")


@app.get("/health")
async def health():
    return {"status": "ok", "llm_provider": config.LLM_PROVIDER}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=config.HOST, port=config.PORT, reload=True)
