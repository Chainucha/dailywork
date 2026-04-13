from fastapi import APIRouter, Depends
from pydantic import BaseModel
from uuid import UUID
from app.dependencies import optional_current_user
from app.supabase_client import get_supabase

router = APIRouter(tags=["categories"])


class CategoryResponse(BaseModel):
    id: UUID
    name: str
    icon_name: str


@router.get("/", response_model=list[CategoryResponse])
async def list_categories(current_user: dict | None = Depends(optional_current_user)):
    db = get_supabase()
    result = db.table("categories").select("*").order("name").execute()
    return result.data or []
