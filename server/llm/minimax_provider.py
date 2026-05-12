import json
import httpx
from .base import LLMProvider
from ..config import config


class MiniMaxProvider(LLMProvider):
    """MiniMax API provider (OpenAI-compatible format)."""

    def __init__(self):
        self.api_key = config.MINIMAX_API_KEY
        self.model = config.MINIMAX_MODEL
        self.base_url = config.MINIMAX_BASE_URL

    async def generate(self, system_prompt: str, user_prompt: str) -> str:
        async with httpx.AsyncClient(trust_env=False) as client:
            response = await client.post(
                f"{self.base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                    "temperature": 0.7,
                    "max_tokens": 256,
                },
                timeout=30.0,
            )
            data = response.json()
            return data["choices"][0]["message"]["content"].strip()

    async def generate_json(self, system_prompt: str, user_prompt: str) -> dict:
        async with httpx.AsyncClient(trust_env=False) as client:
            response = await client.post(
                f"{self.base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": system_prompt + "\nYou MUST respond with valid JSON only."},
                        {"role": "user", "content": user_prompt},
                    ],
                    "temperature": 0.7,
                    "max_tokens": 256,
                },
                timeout=30.0,
            )
            data = response.json()
            content = data["choices"][0]["message"]["content"].strip()
            if content.startswith("```"):
                content = content.split("```")[1]
                if content.startswith("json"):
                    content = content[4:]
            return json.loads(content)
