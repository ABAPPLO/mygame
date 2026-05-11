from abc import ABC, abstractmethod
from typing import Any


class LLMProvider(ABC):
    @abstractmethod
    async def generate(self, system_prompt: str, user_prompt: str) -> str:
        pass

    @abstractmethod
    async def generate_json(self, system_prompt: str, user_prompt: str) -> dict:
        pass
