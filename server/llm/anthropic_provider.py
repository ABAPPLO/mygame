import json
import anthropic
from .base import LLMProvider
from ..config import config


class AnthropicProvider(LLMProvider):
    def __init__(self):
        self.client = anthropic.AsyncAnthropic(api_key=config.ANTHROPIC_API_KEY)
        self.model = config.ANTHROPIC_MODEL

    async def generate(self, system_prompt: str, user_prompt: str) -> str:
        response = await self.client.messages.create(
            model=self.model,
            max_tokens=256,
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}],
        )
        return response.content[0].text.strip()

    async def generate_json(self, system_prompt: str, user_prompt: str) -> dict:
        json_instruction = "You MUST respond with valid JSON only. No markdown, no explanation."
        full_system = f"{system_prompt}\n{json_instruction}"
        response = await self.client.messages.create(
            model=self.model,
            max_tokens=256,
            system=full_system,
            messages=[{"role": "user", "content": user_prompt}],
        )
        content = response.content[0].text.strip()
        if content.startswith("```"):
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]
        return json.loads(content)
