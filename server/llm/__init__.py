from .base import LLMProvider
from .openai_provider import OpenAIProvider
from .anthropic_provider import AnthropicProvider
from .ollama_provider import OllamaProvider
from .minimax_provider import MiniMaxProvider
from ..config import config


def get_provider() -> LLMProvider:
    providers = {
        "openai": OpenAIProvider,
        "anthropic": AnthropicProvider,
        "ollama": OllamaProvider,
        "minimax": MiniMaxProvider,
    }
    provider_class = providers.get(config.LLM_PROVIDER)
    if not provider_class:
        raise ValueError(f"Unknown LLM provider: {config.LLM_PROVIDER}")
    return provider_class()
