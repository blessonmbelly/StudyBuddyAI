"""
StudyBuddy AI - Backend Authentication Test Suite Runner
Runs all 21 authentication unit, validation, and route flow tests.
"""
import sys
from pathlib import Path

# Ensure Windows terminal doesn't crash on utf-8 characters
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# Ensure backend root is in sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

import tests.test_auth as t


def run_coroutine(coro):
    """Executes a coroutine and its awaits without opening network loopback sockets."""
    stack = [coro]
    result = None
    while stack:
        current = stack[-1]
        try:
            val = current.send(result)
            if hasattr(val, "send"):
                stack.append(val)
                result = None
            elif hasattr(val, "__await__"):
                stack.append(val.__await__())
                result = None
            else:
                result = val
        except StopIteration as e:
            stack.pop()
            result = e.value
    return result


def run_test(test_fn, name: str):
    try:
        if hasattr(test_fn, "__code__") and test_fn.__code__.co_flags & 0x80:  # CO_COROUTINE
            run_coroutine(test_fn())
        else:
            test_fn()
        print(f"  [PASS] {name}")
        return True
    except Exception as e:
        print(f"  [FAIL] {name}: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    print("=" * 75)
    print(" PHASE 2: SECURE BACKEND AUTHENTICATION TEST SUITE")
    print("=" * 75)

    passed = 0
    total = 0

    test_cases = [
        # 1. Password Hashing & Security
        (t.test_password_hashing_and_verification, "Password Hashing & Salted Bcrypt Verification"),
        (t.test_password_salting_unique, "Bcrypt Unique Salt Generation for Identical Passwords"),
        (t.test_password_empty_rejected, "Empty Password Rejection"),
        
        # 2. JWT Access Tokens
        (t.test_access_token_creation_and_decoding, "JWT Access Token Creation & Claims (sub, email, exp, iat)"),
        (t.test_expired_token_rejected, "Expired Access Token Rejection (HTTP 401)"),
        (t.test_tampered_token_rejected, "Tampered Token Signature Rejection (HTTP 401)"),
        
        # 3. Refresh Tokens & Hashing
        (t.test_refresh_token_generation_and_hashing, "High-Entropy Refresh Token & SHA-256 Hash Verification"),
        
        # 4. Email Normalization & Input Validation
        (t.test_email_normalization_on_registration_and_login, "Email Normalization (Case-folding & Whitespace Trimming)"),
        (t.test_invalid_email_format_rejected, "Malformed Email Format Rejection"),
        (t.test_short_password_rejected, "Short Password (<8 chars) Rejection"),
        
        # 5. Production Secret Key Safety
        (t.test_production_secret_fail_safe, "Production Secret Key Fail-Safe Enforcement (<32 chars / missing)"),
        
        # 6. Registration Flow
        (t.test_register_user_success, "Registration Flow & Token Pair Issuance (HTTP 201)"),
        (t.test_register_duplicate_email_conflict, "Duplicate Email Registration Conflict (HTTP 409)"),
        
        # 7. Login Flow
        (t.test_login_user_success, "Successful Login with Valid Credentials (HTTP 200)"),
        (t.test_login_wrong_password_rejected, "Failed Login with Wrong Password (HTTP 401 Generic Safe Message)"),
        (t.test_login_nonexistent_email_rejected, "Failed Login with Nonexistent Email (HTTP 401 Generic Safe Message)"),
        
        # 8. Refresh Token Rotation Flow
        (t.test_refresh_token_rotation_success, "Refresh Token Rotation & New Token Issuance (HTTP 200)"),
        (t.test_refresh_revoked_token_rejected, "Revoked Refresh Token Rejection (HTTP 401)"),
        
        # 9. Logout Flow
        (t.test_logout_revokes_refresh_token, "Logout & Refresh Token Invalidation"),
        
        # 10. Protected Routes & Dependencies
        (t.test_get_my_profile_authenticated, "Protected /api/auth/me Profile Return"),
        (t.test_get_current_user_missing_token, "Protected Route Without Bearer Token Rejection (HTTP 401)"),
    ]

    for fn, name in test_cases:
        total += 1
        if run_test(fn, name):
            passed += 1

    print("\n" + "=" * 75)
    print(f" TEST RUN COMPLETED: {passed}/{total} TESTS PASSED")
    print("=" * 75)

    if passed != total:
        sys.exit(1)


if __name__ == "__main__":
    main()
