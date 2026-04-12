from supabase import create_client, Client
from app.config import settings

_client: Client | None = None


def get_supabase() -> Client:
    """Singleton DB client — always uses the service role key, bypasses RLS.
    Never call auth sign-in/verify methods on this client; those operations
    set the user session internally and would replace the service role key
    with the user's JWT for subsequent PostgREST calls.
    """
    global _client
    if _client is None:
        _client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    return _client


def get_auth_client() -> Client:
    """Fresh auth-only client per call.
    Used exclusively for Supabase Auth operations (send-otp, verify-otp,
    refresh, sign-out). Creating a new instance each time means session
    changes from auth flows never contaminate the shared DB client above.
    """
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
