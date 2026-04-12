from app.config import Settings


def test_jwks_url_derived_from_supabase_url():
    """JWKS URL should default to {SUPABASE_URL}/auth/v1/.well-known/jwks.json"""
    s = Settings(
        _env_file=None,
        SUPABASE_URL="https://abc.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="srk",
    )
    assert s.SUPABASE_JWKS_URL == "https://abc.supabase.co/auth/v1/.well-known/jwks.json"


def test_jwt_secret_is_optional():
    """HS256 fallback secret should default to empty string."""
    s = Settings(
        _env_file=None,
        SUPABASE_URL="https://abc.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="srk",
    )
    assert s.SUPABASE_JWT_SECRET == ""
