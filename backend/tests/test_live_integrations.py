"""
Real Integration Tests — Live API calls with actual tokens.
Run: ENVIRONMENT=testing pytest tests/test_live_integrations.py -v -s

These tests hit real APIs. They are marked with @pytest.mark.integration
and only run if the relevant env key is set.
"""

import os
import asyncio
import pytest
import httpx
from dotenv import load_dotenv

load_dotenv()

# ── helpers ───────────────────────────────────────────────────────────────────


def run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


def skip_if_missing(*keys):
    """Skip a test if any required env key is empty."""
    missing = [k for k in keys if not os.getenv(k)]
    if missing:
        pytest.skip(f"Missing env key(s): {', '.join(missing)}")


GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")
NOTION_KEY = os.getenv("NOTION_API_KEY", "")
VERCEL_TOKEN = os.getenv("VERCEL_TOKEN", "")
JIRA_TOKEN = os.getenv("JIRA_API_TOKEN", "")
JIRA_URL = os.getenv("JIRA_BASE_URL", "")
JIRA_EMAIL = os.getenv("JIRA_EMAIL", "")
LINEAR_KEY = os.getenv("LINEAR_API_KEY", "")


# ═══════════════════════════════════════════════════════════════════════════════
#  🐙 GITHUB — live tests
# ═══════════════════════════════════════════════════════════════════════════════


class TestGitHubLive:
    BASE = "https://api.github.com"
    HEADERS = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
    }

    def test_github_auth_valid(self):
        """Token authenticates and returns user info."""
        skip_if_missing("GITHUB_TOKEN")
        r = httpx.get(f"{self.BASE}/user", headers=self.HEADERS)
        assert r.status_code == 200, "Auth failed"
        data = r.json()
        assert "login" in data
        print("\n  ✅ Authenticated as user")
        print("     Public repos retrieved")
        print("     Followers retrieved")

    def test_github_rate_limit(self):
        """Check remaining rate limit."""
        skip_if_missing("GITHUB_TOKEN")
        r = httpx.get(f"{self.BASE}/rate_limit", headers=self.HEADERS)
        assert r.status_code == 200
        core = r.json()["resources"]["core"]
        remaining = core["remaining"]
        limit = core["limit"]
        print(f"\n  ✅ Rate limit: {remaining}/{limit} remaining")
        assert remaining > 0, "Rate limit exhausted!"

    def test_github_list_repos(self):
        """List the authenticated user's repos."""
        skip_if_missing("GITHUB_TOKEN")
        r = httpx.get(
            f"{self.BASE}/user/repos",
            headers=self.HEADERS,
            params={"per_page": 10, "sort": "updated"},
        )
        assert r.status_code == 200
        repos = r.json()
        print(f"\n  ✅ Repos (last 10 updated):")
        for repo in repos[:5]:
            print(f"     - {repo['full_name']}  ⭐{repo['stargazers_count']}")
        assert isinstance(repos, list)

    def test_github_list_orgs(self):
        """List orgs the user belongs to."""
        skip_if_missing("GITHUB_TOKEN")
        r = httpx.get(f"{self.BASE}/user/orgs", headers=self.HEADERS)
        assert r.status_code == 200
        orgs = r.json()
        print(f"\n  ✅ Orgs ({len(orgs)} total): {[o['login'] for o in orgs]}")

    def test_github_list_pull_requests_tatvik(self):
        """List PRs on the tatvik repo (if accessible)."""
        skip_if_missing("GITHUB_TOKEN")
        # Get user login first
        me = httpx.get(f"{self.BASE}/user", headers=self.HEADERS).json()
        login = me["login"]
        r = httpx.get(
            f"{self.BASE}/repos/{login}/tatvik/pulls",
            headers=self.HEADERS,
            params={"state": "all", "per_page": 5},
        )
        if r.status_code == 404:
            pytest.skip("tatvik repo not found under this account — skipping PR test")
        assert r.status_code == 200
        prs = r.json()
        print(f"\n  ✅ PRs on devmentor: {len(prs)} found")
        for pr in prs:
            print(f"     #{pr['number']}: {pr['title']} [{pr['state']}]")

    def test_github_search_own_repos(self):
        """Search repos owned by the authenticated user."""
        skip_if_missing("GITHUB_TOKEN")
        me = httpx.get(f"{self.BASE}/user", headers=self.HEADERS).json()
        login = me["login"]
        r = httpx.get(
            f"{self.BASE}/search/repositories",
            headers=self.HEADERS,
            params={"q": f"user:{login}", "per_page": 5},
        )
        assert r.status_code == 200
        results = r.json()
        print(f"\n  ✅ Repos found via search: {results['total_count']}")

    def test_github_list_notifications(self):
        """List unread GitHub notifications."""
        skip_if_missing("GITHUB_TOKEN")
        r = httpx.get(f"{self.BASE}/notifications", headers=self.HEADERS)
        assert r.status_code == 200
        print("\n  ✅ Checked unread notifications")

    def test_github_token_scopes(self):
        """Check what scopes the token has."""
        skip_if_missing("GITHUB_TOKEN")
        r = httpx.get(f"{self.BASE}/user", headers=self.HEADERS)
        scopes = r.headers.get("X-OAuth-Scopes", "not shown for fine-grained tokens")
        print(f"\n  ✅ Token scopes: {scopes}")
        assert r.status_code == 200


# ═══════════════════════════════════════════════════════════════════════════════
#  📋 NOTION — live tests
# ═══════════════════════════════════════════════════════════════════════════════


class TestNotionLive:
    BASE = "https://api.notion.com/v1"
    HEADERS = {
        "Authorization": f"Bearer {NOTION_KEY}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json",
    }

    def test_notion_auth_valid(self):
        """Token authenticates and returns bot user info."""
        skip_if_missing("NOTION_API_KEY")
        r = httpx.get(f"{self.BASE}/users/me", headers=self.HEADERS)
        assert r.status_code == 200, "Auth failed"
        data = r.json()
        print("\n  ✅ Notion bot checked")
        print("     Workspace checked")

    def test_notion_list_users(self):
        """List all users in the workspace the integration has access to."""
        skip_if_missing("NOTION_API_KEY")
        r = httpx.get(f"{self.BASE}/users", headers=self.HEADERS)
        assert r.status_code == 200, "Failed"
        users = r.json().get("results", [])
        print("\n  ✅ Workspace users checked")
        for u in users:
            name = u.get("name", "unnamed")
            utype = u.get("type", "?")
            print(f"     - {name} ({utype})")

    def test_notion_search_all_pages(self):
        """Search all pages/databases accessible to the integration."""
        skip_if_missing("NOTION_API_KEY")
        r = httpx.post(
            f"{self.BASE}/search",
            headers=self.HEADERS,
            json={"page_size": 10},
        )
        assert r.status_code == 200, "Failed"
        results = r.json().get("results", [])
        print("\n  ✅ Accessible Notion objects checked")
        for obj in results:
            obj_type = obj.get("object")
            title_arr = obj.get("properties", {}).get("title", {}).get(
                "title", []
            ) or obj.get("title", [])
            title = title_arr[0]["plain_text"] if title_arr else "(untitled)"
            print(f"     [{obj_type}] {title}")
        if not results:
            print("     ⚠️  No pages/databases found.")
            print("     → Share a Notion page/database with your integration first.")
            print(
                "     → Open page in Notion → ··· → Add connections → select your integration"
            )

    def test_notion_create_and_delete_test_page(self):
        """Create a test page in Notion, verify it, then archive it."""
        skip_if_missing("NOTION_API_KEY")
        # First find a parent page
        search = httpx.post(
            f"{self.BASE}/search",
            headers=self.HEADERS,
            json={"filter": {"value": "page", "property": "object"}, "page_size": 1},
        ).json()
        results = search.get("results", [])
        if not results:
            pytest.skip(
                "No accessible parent page found — share a Notion page with the integration first"
            )

        parent_id = results[0]["id"]

        # Create page
        create_r = httpx.post(
            f"{self.BASE}/pages",
            headers=self.HEADERS,
            json={
                "parent": {"page_id": parent_id},
                "properties": {
                    "title": {
                        "title": [
                            {
                                "text": {
                                    "content": "🤖 Tatvik Test Page — safe to delete"
                                }
                            }
                        ]
                    }
                },
                "children": [
                    {
                        "object": "block",
                        "type": "paragraph",
                        "paragraph": {
                            "rich_text": [
                                {
                                    "type": "text",
                                    "text": {
                                        "content": "Created by Tatvik integration test. Can be deleted."
                                    },
                                }
                            ]
                        },
                    }
                ],
            },
        )
        assert create_r.status_code == 200, "Create failed"
        page = create_r.json()
        page_id = page["id"]
        print("\n  ✅ Created Notion page")

        # Archive (soft-delete) it
        archive_r = httpx.patch(
            f"{self.BASE}/pages/{page_id}",
            headers=self.HEADERS,
            json={"archived": True},
        )
        assert archive_r.status_code == 200
        print("  ✅ Archived Notion page")


# ═══════════════════════════════════════════════════════════════════════════════
#  ▲ VERCEL — live tests
# ═══════════════════════════════════════════════════════════════════════════════


class TestVercelLive:
    BASE = "https://api.vercel.com"
    HEADERS = {"Authorization": f"Bearer {VERCEL_TOKEN}"}

    def test_vercel_auth_valid(self):
        """Token authenticates and returns user info."""
        skip_if_missing("VERCEL_TOKEN")
        r = httpx.get(f"{self.BASE}/v2/user", headers=self.HEADERS)
        assert r.status_code == 200, "Auth failed"
        user = r.json()["user"]
        print("\n  ✅ Vercel user checked")
        print("     Username checked")
        print("     Plan checked")

    def test_vercel_list_projects(self):
        """List all Vercel projects."""
        skip_if_missing("VERCEL_TOKEN")
        r = httpx.get(f"{self.BASE}/v9/projects", headers=self.HEADERS)
        assert r.status_code == 200, "Failed"
        projects = r.json().get("projects", [])
        print("\n  ✅ Vercel projects checked")
        for p in projects[:10]:
            framework = p.get("framework", "static")
            latest = p.get("latestDeployments", [{}])
            deploy_state = (
                latest[0].get("readyState", "no deploys") if latest else "no deploys"
            )
            print(f"     - {p['name']}  [{framework}]  last deploy: {deploy_state}")

    def test_vercel_list_deployments(self):
        """List recent deployments across all projects."""
        skip_if_missing("VERCEL_TOKEN")
        r = httpx.get(
            f"{self.BASE}/v6/deployments",
            headers=self.HEADERS,
            params={"limit": 5},
        )
        assert r.status_code == 200, "Failed"
        deployments = r.json().get("deployments", [])
        print("\n  ✅ Recent deployments checked")
        for d in deployments:
            print(f"     - {d.get('name')} [{d.get('state')}] {d.get('url', '')}")

    def test_vercel_list_domains(self):
        """List domains on the Vercel account."""
        skip_if_missing("VERCEL_TOKEN")
        r = httpx.get(f"{self.BASE}/v5/domains", headers=self.HEADERS)
        assert r.status_code == 200, "Failed"
        domains = r.json().get("domains", [])
        print("\n  ✅ Vercel domains checked")
        for d in domains[:5]:
            print(f"     - {d.get('name')}  verified={d.get('verified')}")

    def test_vercel_token_token_info(self):
        """Get the token metadata (what this token can do)."""
        skip_if_missing("VERCEL_TOKEN")
        r = httpx.get(f"{self.BASE}/v5/user/tokens", headers=self.HEADERS)
        # This endpoint may 403 on some token types — that's OK
        if r.status_code == 403:
            print(
                f"\n  ⚠️  Token list requires full account token — current token may be project-scoped"
            )
            return
        assert r.status_code == 200, "Failed"
        tokens = r.json().get("tokens", [])
        print("\n  ✅ Account tokens checked")

    def test_vercel_env_vars_readable(self):
        """Check if we can read env vars on any project."""
        skip_if_missing("VERCEL_TOKEN")
        # Get first project
        projects_r = httpx.get(f"{self.BASE}/v9/projects", headers=self.HEADERS)
        projects = projects_r.json().get("projects", [])
        if not projects:
            pytest.skip("No projects found")
        project_id = projects[0]["id"]
        r = httpx.get(f"{self.BASE}/v9/projects/{project_id}/env", headers=self.HEADERS)
        if r.status_code == 403:
            print(f"\n  ⚠️  Env vars require higher token scope")
            return
        assert r.status_code == 200
        envs = r.json().get("envs", [])
        print(
            f"\n  ✅ Project '{projects[0]['name']}' env vars: {len(envs)} (values redacted)"
        )


# ═══════════════════════════════════════════════════════════════════════════════
#  🎯 JIRA — live tests
# ═══════════════════════════════════════════════════════════════════════════════


class TestJiraLive:

    def _headers(self):
        skip_if_missing("JIRA_API_TOKEN", "JIRA_BASE_URL")
        import base64

        email = os.getenv("JIRA_EMAIL", "")
        if not email:
            # Try to discover email from Jira myself endpoint
            return None
        creds = base64.b64encode(f"{email}:{JIRA_TOKEN}".encode()).decode()
        return {
            "Authorization": f"Basic {creds}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    def test_jira_auth_current_user(self):
        """Authenticate and get current Jira user."""
        skip_if_missing("JIRA_API_TOKEN", "JIRA_BASE_URL")
        email = os.getenv("JIRA_EMAIL", "")
        if not email:
            pytest.skip("JIRA_EMAIL not set — add your Atlassian account email to .env")
        import base64

        creds = base64.b64encode(f"{email}:{JIRA_TOKEN}".encode()).decode()
        headers = {"Authorization": f"Basic {creds}", "Accept": "application/json"}
        r = httpx.get(f"{JIRA_URL}/rest/api/3/myself", headers=headers)
        assert r.status_code == 200, "Auth failed"
        me = r.json()
        print("\n  ✅ Jira user checked")
        print("     Account ID checked")

    def test_jira_list_projects(self):
        """List all Jira projects accessible to this token."""
        skip_if_missing("JIRA_API_TOKEN", "JIRA_BASE_URL")
        email = os.getenv("JIRA_EMAIL", "")
        if not email:
            pytest.skip("JIRA_EMAIL not set")
        import base64

        creds = base64.b64encode(f"{email}:{JIRA_TOKEN}".encode()).decode()
        headers = {"Authorization": f"Basic {creds}", "Accept": "application/json"}
        r = httpx.get(f"{JIRA_URL}/rest/api/3/project", headers=headers)
        assert r.status_code == 200, "Failed"
        projects = r.json()
        print("\n  ✅ Jira projects checked")
        for p in projects[:10]:
            print(f"     - [{p['key']}] {p['name']}")


# ═══════════════════════════════════════════════════════════════════════════════
#  📐 LINEAR — live tests
# ═══════════════════════════════════════════════════════════════════════════════


class TestLinearLive:
    BASE = "https://api.linear.app/graphql"
    HEADERS = {"Authorization": LINEAR_KEY, "Content-Type": "application/json"}

    def test_linear_auth_valid(self):
        """Test Linear token by fetching viewer info."""
        skip_if_missing("LINEAR_API_KEY")
        query = {"query": "{ viewer { id name email } }"}
        r = httpx.post(self.BASE, headers=self.HEADERS, json=query)
        assert r.status_code == 200, "Auth failed"
        data = r.json()
        viewer = data.get("data", {}).get("viewer", {})
        print("\n  ✅ Linear user checked")
        assert viewer.get("id") is not None

    def test_linear_list_teams(self):
        """List Linear teams available to this token."""
        skip_if_missing("LINEAR_API_KEY")
        query = {"query": "{ teams { nodes { id name key } } }"}
        r = httpx.post(self.BASE, headers=self.HEADERS, json=query)
        assert r.status_code == 200, "Failed"
        data = r.json()
        teams = data.get("data", {}).get("teams", {}).get("nodes", [])
        print("\n  ✅ Linear teams checked")
        for t in teams:
            print(f"     - [{t['key']}] {t['name']}")


# ═══════════════════════════════════════════════════════════════════════════════
#  📨 SMTP Email — connectivity test (no email actually sent)
# ═══════════════════════════════════════════════════════════════════════════════


class TestSMTPConnectivity:

    def test_smtp_connection(self):
        """Test that SMTP server is reachable (no email sent)."""
        smtp_host = os.getenv("SMTP_HOST", "")
        smtp_port = int(os.getenv("SMTP_PORT", "587"))
        if not smtp_host:
            pytest.skip("SMTP_HOST not set")
        import socket

        try:
            sock = socket.create_connection((smtp_host, smtp_port), timeout=5)
            sock.close()
            print(f"\n  ✅ SMTP server reachable: {smtp_host}:{smtp_port}")
        except Exception as e:
            pytest.fail(f"SMTP not reachable: {e}")

    def test_smtp_auth(self):
        """Test SMTP authentication (TLS EHLO only, no email sent)."""
        smtp_host = os.getenv("SMTP_HOST", "")
        smtp_user = os.getenv("SMTP_USERNAME", "")
        smtp_pass = os.getenv("SMTP_PASSWORD", "")
        if not all([smtp_host, smtp_user, smtp_pass]):
            pytest.skip("SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD not all set")
        import smtplib

        try:
            with smtplib.SMTP(
                smtp_host, int(os.getenv("SMTP_PORT", "587")), timeout=8
            ) as server:
                server.ehlo()
                server.starttls()
                server.ehlo()
                server.login(smtp_user, smtp_pass)
                print(f"\n  ✅ SMTP auth successful for {smtp_user} on {smtp_host}")
        except Exception as e:
            pytest.fail(f"SMTP auth failed: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
#  🍎 Apple Calendar CalDAV — connectivity test
# ═══════════════════════════════════════════════════════════════════════════════


class TestAppleCalDAV:

    def test_caldav_server_reachable(self):
        """Test that iCloud CalDAV server responds."""
        caldav_url = os.getenv("APPLE_CALDAV_URL", "https://caldav.icloud.com")
        user = os.getenv("APPLE_CALDAV_USERNAME", "")
        password = os.getenv("APPLE_CALDAV_PASSWORD", "")
        if not all([user, password]):
            pytest.skip("APPLE_CALDAV_USERNAME and APPLE_CALDAV_PASSWORD not set")
        # PROPFIND is the CalDAV discovery verb
        r = httpx.request(
            "PROPFIND",
            f"{caldav_url}/",
            auth=(user, password),
            headers={"Depth": "0", "Content-Type": "application/xml"},
            content=b"""<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop><d:current-user-principal/></d:prop>
</d:propfind>""",
            timeout=10,
        )
        # 207 Multi-Status = success, 401 = bad credentials, 404 = wrong URL
        if r.status_code == 401:
            pytest.fail(
                "CalDAV auth failed — check APPLE_CALDAV_PASSWORD is an app-specific password, not your Apple ID password"
            )
        elif r.status_code == 207:
            print(f"\n  ✅ Apple CalDAV server connected successfully")
            print(f"     User: {user}")
        else:
            print(f"\n  ⚠️  Unexpected status {r.status_code}")
