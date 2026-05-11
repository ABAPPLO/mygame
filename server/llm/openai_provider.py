import json
from openai import AsyncOpenAI
from .base import LLMProvider
from ..config import config


class OpenAIProvider(LLMProvider):
    def __init__(self):
        self.client = AsyncOpenAI(
            api_key=config.OPENAI_API_KEY,
            base_url=config.OPENAI_BASE_URL,
        )
        self.model = config.OPENAI_MODEL

    async def generate(self, system_prompt: str, user_prompt: str) -> str:
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.7,
            max_tokens=256,
        )
        return response.choices[0].message.content.strip()

    async def generate_json(self, system_prompt: str, user_prompt: str) -> dict:
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.7,
            max_tokens=256,
            response_format={"type": "json_object"},
        )
        content = response.choices[0].message.content.strip()
        return json.loads(content)
