from pydantic import BaseModel, UUID4
from datetime import datetime
from typing import Literal


class ApplicationResponse(BaseModel):
    id: UUID4
    job_id: UUID4
    worker_id: UUID4
    status: str
    created_at: datetime
    updated_at: datetime
    withdrawn_reason: str | None = None


class ApplicationStatusUpdate(BaseModel):
    status: Literal["accepted", "rejected", "withdrawn"]
    reason: str | None = None


class ApplicantResponse(BaseModel):
    application_id: UUID4
    worker_id: UUID4
    status: str
    created_at: datetime
    display_name: str | None = None
    phone_number: str | None = None
    rating_avg: float | None = None


class ApplicantListResponse(BaseModel):
    data: list[ApplicantResponse]
