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


class ApplicationStatusUpdate(BaseModel):
    status: Literal["accepted", "rejected", "withdrawn"]
