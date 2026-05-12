import json
import httpx
from .base import LLMProvider
from ..config import config


class OllamaProvider(LLMProvider):
    def __init__(self):
        self.base_url = config.OLLAMA_BASE_URL
        self.model = config.OLLAMA_MODEL

    async def generate(self, system_prompt: str, user_prompt: str) -> str:
        async with httpx.AsyncClient(trust_env=False) as client:
            response = await client.post(
                f"{self.base_url}/api/generate",
                json={
                    "model": self.model,
                    "prompt": f"{system_prompt}\n\n{user_prompt}",
                    "stream": False,
                    "options": {"temperature": 0.7, "num_predict": 256},
                },
                timeout=30.0,
            )
            data = response.json()
            return data.get("response", "").strip()

    async def generate_json(self, system_prompt: str, user_prompt: str) -> dict:
        json_instruction = "You MUST respond with valid JSON only. No markdown, no explanation."
        full_prompt = f"{system_prompt}\n{json_instruction}\n\n{user_prompt}"
        async with httpx.AsyncClient(trust_env=False) as client:
            response = await client.post(
                f"{self.base_url}/api/generate",
                json={
                    "model": self.model,
                    "prompt": full_prompt,
                    "stream": False,
                    "format": "json",
                    "options": {"temperature": 0.7, "num_predict": 256},
                },
                timeout=30.0,
            )
            data = response.json()
            content = data.get("response", "").strip()
            return json.loads(content)
