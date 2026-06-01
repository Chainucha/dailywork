from pydantic import BaseModel, field_validator
from uuid import UUID
from datetime import datetime


class ReviewCreate(BaseModel):
    reviewee_id: UUID
    job_id: UUID
    rating: int
    comment: str | None = None

    @field_validator("rating")
    @classmethod
    def rating_range(cls, v: int) -> int:
        if not 1 <= v <= 5:
            raise ValueError("rating must be between 1 and 5")
        return v


class ReviewResponse(BaseModel):
    id: UUID
    reviewer_id: UUID
    reviewee_id: UUID
    job_id: UUID
    rating: int
    comment: str | None = None
    created_at: datetime


class ReviewListItem(BaseModel):
    id: UUID
    rating: int
    comment: str | None = None
    created_at: datetime
    reviewer_display_name: str


class ReviewListResponse(BaseModel):
    items: list[ReviewListItem]
    total: int
    limit: int
    offset: int
