import json
import os
import random
from typing import Any, Dict, List, Union
from fastapi import APIRouter, HTTPException
from ..config import config

router = APIRouter(prefix="/game", tags=["Game"])


def _load_json(filename: str) -> Any:
    path = os.path.join(config.GAME_DATA_PATH, filename)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


@router.get("/heroes")
async def get_hero_templates():
    return _load_json("heroes.json")


@router.get("/equipment")
async def get_equipment():
    return _load_json("equipment.json")


@router.get("/monsters")
async def get_monsters():
    return _load_json("monsters.json")


@router.get("/buildings")
async def get_buildings():
    return _load_json("buildings.json")


@router.get("/tavern/refresh")
async def refresh_tavern():
    heroes = _load_json("heroes.json")
    count = random.randint(1, 2)
    available = random.sample(heroes, min(count, len(heroes)))
    return {"heroes": available, "refresh_cost": 10}


@router.get("/map/generate")
async def generate_map(seed: int = None):
    if seed is None:
        seed = random.randint(1, 999999)
    random.seed(seed)

    map_size = 32
    tile_types = ["grass", "grass", "grass", "forest", "mountain", "water"]
    tiles = []
    for y in range(map_size):
        row = []
        for x in range(map_size):
            tile = random.choice(tile_types)
            row.append({"type": tile, "x": x, "y": y})
        tiles.append(row)

    monsters = _load_json("monsters.json")
    monster_count = random.randint(8, 15)
    monster_positions = []
    for _ in range(monster_count):
        mx = random.randint(3, map_size - 3)
        my = random.randint(3, map_size - 3)
        m = random.choice(monsters)
        monster_positions.append({
            "monster_id": m["id"],
            "name": m["name"],
            "x": mx,
            "y": my,
            "stats": m["stats"],
        })

    resource_count = random.randint(6, 12)
    resource_positions = []
    resource_types = ["gold_vein", "wood", "stone", "crystal"]
    for _ in range(resource_count):
        rx = random.randint(1, map_size - 1)
        ry = random.randint(1, map_size - 1)
        resource_positions.append({
            "type": random.choice(resource_types),
            "x": rx,
            "y": ry,
            "amount": random.randint(5, 20),
        })

    return {
        "seed": seed,
        "size": map_size,
        "tiles": tiles,
        "monsters": monster_positions,
        "resources": resource_positions,
        "town_position": {"x": 1, "y": 1},
    }
