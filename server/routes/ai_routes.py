import logging
from fastapi import APIRouter, HTTPException
from ..llm import get_provider
from ..llm.prompt_templates import EXPLORATION_SYSTEM, EXPLORATION_USER, COMBAT_SYSTEM, COMBAT_USER
from ..models.decision import ExplorationRequest, ExplorationDecision, CombatRequest, CombatDecision

router = APIRouter(prefix="/ai", tags=["AI"])
logger = logging.getLogger(__name__)


@router.post("/explore", response_model=ExplorationDecision)
async def explore_decision(req: ExplorationRequest):
    system_prompt = EXPLORATION_SYSTEM.format(
        hero_name=req.hero_name,
        hero_class=req.hero_class,
        personality=req.personality,
        level=req.level,
        hp=req.hp,
        max_hp=req.max_hp,
        troops=req.troops,
        talent_name=req.talent_name,
        talent_desc=req.talent_desc,
        suggested_target=req.suggested_target,
        suggested_action=req.suggested_action,
        suggested_direction=req.suggested_direction,
    )
    user_prompt = EXPLORATION_USER.format(
        x=req.x,
        y=req.y,
        visible_info=req.visible_info,
        nearby_enemies=req.nearby_enemies,
        nearby_resources=req.nearby_resources,
        town_distance=req.town_distance,
        hero_name=req.hero_name,
    )
    try:
        provider = get_provider()
        result = await provider.generate_json(system_prompt, user_prompt)
        return ExplorationDecision(**result)
    except Exception as e:
        logger.error(f"LLM exploration decision failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/combat", response_model=CombatDecision)
async def combat_decision(req: CombatRequest):
    system_prompt = COMBAT_SYSTEM.format(
        hero_name=req.hero_name,
        hero_class=req.hero_class,
        personality=req.personality,
        hp=req.hp,
        max_hp=req.max_hp,
        troop_hp=req.troop_hp,
        skills=req.skills,
        cooldowns=req.cooldowns,
    )
    user_prompt = COMBAT_USER.format(
        enemies=req.enemies,
        turn=req.turn,
        hero_name=req.hero_name,
    )
    try:
        provider = get_provider()
        result = await provider.generate_json(system_prompt, user_prompt)
        return CombatDecision(**result)
    except Exception as e:
        logger.error(f"LLM combat decision failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
