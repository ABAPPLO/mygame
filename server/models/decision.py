from pydantic import BaseModel
from typing import Optional, Dict, List, Any


class ExplorationRequest(BaseModel):
    hero_id: str
    hero_name: str
    hero_class: str
    personality: str
    level: int
    hp: int
    max_hp: int
    troops: int
    talent_name: str
    talent_desc: str
    x: int
    y: int
    visible_info: str
    nearby_enemies: str
    nearby_resources: str
    town_distance: int


class ExplorationDecision(BaseModel):
    action: str  # move, attack, gather, rest, return_town
    direction: Optional[str] = None  # north, south, east, west
    target: Optional[str] = None
    reason: str = ""


class CombatRequest(BaseModel):
    hero_id: str
    hero_name: str
    hero_class: str
    personality: str
    hp: int
    max_hp: int
    troop_hp: int
    skills: str
    cooldowns: str
    enemies: str
    turn: int


class CombatDecision(BaseModel):
    skill_id: str  # skill_id or "auto_attack"
    target: str
    reason: str = ""
