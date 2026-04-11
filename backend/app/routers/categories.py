from fastapi import APIRouter, Depends
from pydantic import BaseModel, UUID4
from app.dependencies import get_current_user
from app.supabase_client import get_supabase

router = APIRouter(tags=["categories"])


class CategoryResponse(BaseModel):
    id: UUID4
    name: str
    icon_name: str


@router.get("/", response_model=list[CategoryResponse])
async def list_categories(current_user: dict = Depends(get_current_user)):
    db = get_supabase()
    result = db.table("categories").select("*").order("name").execute()
    return result.data or []
