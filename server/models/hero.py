from pydantic import BaseModel
from typing import Optional, Dict, List


class HeroStats(BaseModel):
    hp: int = 100
    max_hp: int = 100
    atk: int = 10
    defense: int = 5
    spd: int = 8
    magic: int = 0


class HeroTalent(BaseModel):
    id: str
    name: str
    description: str


class HeroSkill(BaseModel):
    id: str
    name: str
    description: str
    damage_multiplier: float = 1.0
    cooldown: int = 3
    current_cooldown: int = 0
    skill_type: str = "offensive"


class Hero(BaseModel):
    id: str
    name: str
    hero_class: str
    personality: str
    level: int = 1
    exp: int = 0
    stats: HeroStats
    talent: HeroTalent
    skills: List[HeroSkill] = []
    equipment_weapon: Optional[str] = None
    equipment_armor: Optional[str] = None
    troops: int = 0
    max_troops: int = 20
    pos_x: int = 0
    pos_y: int = 0
    in_town: bool = True
