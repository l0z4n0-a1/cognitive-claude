#!/usr/bin/env python3
"""
cognitive-claude / tools / test_redaction.py
==============================================

Stdlib-only test for the secret-redaction regex used in
hooks/telemetry.sh. The regex is duplicated here (single source of
truth would require a python module the bash hook could import; that
is more complex than the redundancy is worth for v0.1).

If hooks/telemetry.sh changes its regex list, update SECRET_PATTERNS
below in lockstep, then re-run:

    python3 tools/test_redaction.py

Exit 0 = all patterns matching as documented in SECURITY.md.
Exit 1 = a documented pattern is no longer caught — investigate.
"""

import re
import unittest


# Mirror of hooks/telemetry.sh SECRET_PATTERNS (keep in sync)
SECRET_PATTERNS = [
    re.compile(r'((?:gho|ghp|ghu|ghs|ghr)_[A-Za-z0-9_]{20,})'),
    re.compile(r'(github_pat_[A-Za-z0-9_]{20,})'),
    re.compile(r'(sk-ant-[A-Za-z0-9_-]{20,})'),
    re.compile(r'(sk-[A-Za-z0-9]{20,})'),
    re.compile(r'(AKIA[0-9A-Z]{16})'),
    re.compile(r'(?i)(bearer\s+[A-Za-z0-9_\-\.=]{16,})'),
    re.compile(r'(?i)(token\s+[A-Za-z0-9_\-\.=]{16,})'),
    re.compile(r'(?i)(authorization:\s*\w+\s+[A-Za-z0-9_\-\.=]{16,})'),
]


def redact(s: str) -> str:
    for p in SECRET_PATTERNS:
        s = p.sub('[REDACTED]', s)
    return s


class TestRedaction(unittest.TestCase):

    # --- Documented patterns MUST be redacted ---

    def test_github_pat_gho(self):
        s = 'GITHUB_TOKEN=gho_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        self.assertNotIn('gho_AAAA', redact(s))
        self.assertIn('[REDACTED]', redact(s))

    def test_github_pat_ghp(self):
        self.assertEqual(redact('ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'), '[REDACTED]')

    def test_github_pat_ghu(self):
        self.assertEqual(redact('ghu_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'), '[REDACTED]')

    def test_github_pat_ghs(self):
        self.assertEqual(redact('ghs_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'), '[REDACTED]')

    def test_github_pat_ghr(self):
        self.assertEqual(redact('ghr_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'), '[REDACTED]')

    def test_github_fine_grained_pat(self):
        s = 'github_pat_11ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
        self.assertEqual(redact(s), '[REDACTED]')

    def test_anthropic_api_key(self):
        s = 'sk-ant-AAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        self.assertEqual(redact(s), '[REDACTED]')

    def test_openai_style_key(self):
        s = 'sk-AAAAAAAAAAAAAAAAAAAAAAAA'
        self.assertEqual(redact(s), '[REDACTED]')

    def test_aws_access_key(self):
        s = 'AKIAIOSFODNN7EXAMPLE'  # canonical fake AWS example
        self.assertEqual(redact(s), '[REDACTED]')

    def test_bearer_token(self):
        s = 'curl -H "Authorization: Bearer abcdef1234567890ABCDEF"'
        self.assertNotIn('abcdef1234567890ABCDEF', redact(s))

    def test_authorization_header(self):
        s = 'Authorization: token abcdef1234567890ABCDEF'
        self.assertNotIn('abcdef1234567890ABCDEF', redact(s))

    # --- Patterns that LOOK secret-ish but are NOT documented MUST NOT redact ---

    def test_unknown_gh_prefix_passes_through(self):
        s = 'this is just text ghx_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        self.assertIn('ghx_AAAA', redact(s))

    def test_short_sk_passes_through(self):
        s = 'sk-abc'
        self.assertEqual(redact(s), 'sk-abc')

    def test_normal_text_unchanged(self):
        s = 'This is a normal log line with no secrets.'
        self.assertEqual(redact(s), s)

    # --- Defense-in-depth: realistic Bash command lines ---

    def test_realistic_curl(self):
        s = 'curl -H "Authorization: Bearer ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" https://api.github.com'
        out = redact(s)
        self.assertNotIn('ghp_AAAA', out)

    def test_env_var_export(self):
        # Synthetic test token — same shape as real PATs, never valid against GitHub
        s = 'export GITHUB_TOKEN=gho_TESTTESTTESTTESTTESTTESTTESTTESTTEST'
        out = redact(s)
        self.assertNotIn('gho_TEST', out)
        self.assertIn('[REDACTED]', out)


if __name__ == '__main__':
    unittest.main()
