from pydantic import BaseModel
from typing import Optional


class EnemyState(BaseModel):
    id: str
    name: str
    hp: int
    max_hp: int
    atk: int
    defense: int
    spd: int
