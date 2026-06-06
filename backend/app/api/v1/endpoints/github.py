from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.api.deps import get_current_user_id, get_db
from app.models.entities import GithubProfile, Repository
from app.models.user import User
from app.services.github_service import GithubService

router = APIRouter()


class SyncUsernameRequest(BaseModel):
    username: str


@router.post("/sync-username")
async def sync_username(
    payload: SyncUsernameRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    try:
        github_service = GithubService(db)
        sync_result = await github_service.sync_public_github_data(
            user_id=user_id, username=payload.username
        )
        return {
            "success": True,
            "message": "Public GitHub sync completed",
            "details": sync_result,
        }
    except Exception as e:
        import logging

        logging.getLogger(__name__).error(f"Failed to sync public github data: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to sync public GitHub data: {str(e)}"
        )


@router.post("/connect")
def connect_github(user_id: str = Depends(get_current_user_id)):
    return {"message": "GitHub account connected", "user_id": user_id}


@router.post("/sync")
async def sync_github(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
):
    # Find github profile and access token
    stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
    profile = db.scalar(stmt)
    if not profile or not profile.access_token:
        raise HTTPException(
            status_code=400,
            detail="GitHub profile not connected or access token missing",
        )

    try:
        github_service = GithubService(db)
        sync_result = await github_service.sync_user_github_data(
            user_id=user_id, access_token=profile.access_token
        )
        return {
            "success": True,
            "message": "GitHub sync completed",
            "details": sync_result,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to sync GitHub data: {str(e)}"
        )


@router.get("/profile")
def github_profile(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
):
    stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
    profile = db.scalar(stmt)
    if not profile:
        # Check User table to see if login username is there
        user_stmt = select(User).where(User.id == user_id)
        user = db.scalar(user_stmt)
        if user and user.username:
            return {
                "login": user.username,
                "name": user.name,
                "avatar_url": user.avatar_url,
                "synced_at": None,
            }
        raise HTTPException(status_code=404, detail="GitHub profile not found")

    user_stmt = select(User).where(User.id == user_id)
    user = db.scalar(user_stmt)

    return {
        "login": profile.login,
        "name": user.name if user else profile.login,
        "avatar_url": user.avatar_url if user else None,
        "synced_at": profile.synced_at.isoformat() if profile.synced_at else None,
    }


@router.get("/repositories")
def github_repositories(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
):
    stmt = select(Repository).where(Repository.user_id == user_id)
    repos = db.scalars(stmt).all()
    return {
        "items": [
            {
                "id": r.id,
                "name": r.name,
                "owner": r.owner,
                "full_name": r.full_name,
                "description": r.description,
                "language": r.language,
                "difficulty": r.difficulty,
                "impact_score": r.impact_score,
                "why_recommended": r.why_recommended,
                "stars_count": r.stars_count,
                "forks_count": r.forks_count,
                "watchers_count": r.watchers_count,
                "open_issues_count": r.open_issues_count,
            }
            for r in repos
        ]
    }


@router.get("/languages")
def github_languages(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
):
    stmt = select(Repository).where(Repository.user_id == user_id)
    repos = db.scalars(stmt).all()
    if not repos:
        return {"languages": {}}

    lang_counts = {}
    for r in repos:
        if r.language:
            lang_counts[r.language] = lang_counts.get(r.language, 0) + 1

    total = sum(lang_counts.values())
    if total == 0:
        return {"languages": {}}

    return {
        "languages": {
            lang: round(count / total, 2)
            for lang, count in sorted(
                lang_counts.items(), key=lambda item: item[1], reverse=True
            )
        }
    }


async def get_github_contributions(username: str, access_token: str, year: int) -> list:
    url = "https://api.github.com/graphql"
    headers = {"Authorization": f"bearer {access_token}", "User-Agent": "DevMentor-App"}

    start_date = f"{year}-01-01T00:00:00Z"
    end_date = f"{year}-12-31T23:59:59Z"

    query = """
    query($username: String!, $from: DateTime!, $to: DateTime!) {
      user(login: $username) {
        contributionsCollection(from: $from, to: $to) {
          contributionCalendar {
            weeks {
              contributionDays {
                contributionCount
                date
              }
            }
          }
        }
      }
    }
    """

    variables = {"username": username, "from": start_date, "to": end_date}

    import httpx

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                url,
                json={"query": query, "variables": variables},
                headers=headers,
                timeout=15.0,
            )
            if response.status_code == 200:
                data = response.json()
                weeks = (
                    data.get("data", {})
                    .get("user", {})
                    .get("contributionsCollection", {})
                    .get("contributionCalendar", {})
                    .get("weeks", [])
                )

                contributions = []
                for week in weeks:
                    for day in week.get("contributionDays", []):
                        contributions.append(
                            {
                                "date": day.get("date"),
                                "count": day.get("contributionCount", 0),
                            }
                        )
                return contributions
        except Exception as e:
            import logging

            logging.getLogger(__name__).error(
                f"Error fetching GraphQL contributions: {e}"
            )
    return []


@router.get("/activity")
async def github_activity(
    year: int | None = None,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    import random
    from app.models.entities import GithubProfile

    stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
    profile = db.scalar(stmt)

    # If no year is specified, return last 14 weeks of data (98 days, or 70 days)
    if not year:
        if profile and profile.access_token:
            try:
                from datetime import datetime

                curr_year = datetime.utcnow().year
                real_contribs = await get_github_contributions(
                    profile.login, profile.access_token, curr_year
                )
                if real_contribs:
                    # Get the last 14 weeks (98 days, then take last 70)
                    recent_contribs = real_contribs
                    if len(real_contribs) >= 70:
                        recent_contribs = real_contribs[-70:]
                    return {"activity": recent_contribs}
            except Exception:
                pass

        # Fallback to mock activity contribution heatmap with mock dates
        from datetime import datetime, timedelta

        end = datetime.utcnow()
        activity_values = []
        for i in range(70):
            date_str = (end - timedelta(days=69 - i)).strftime("%Y-%m-%d")
            activity_values.append(
                {"date": date_str, "count": random.choice([0, 0, 1, 2, 4, 8, 10])}
            )
        return {"activity": activity_values}

    # If year is specified, fetch year-wise data
    if profile and profile.access_token:
        try:
            real_contribs = await get_github_contributions(
                profile.login, profile.access_token, year
            )
            if real_contribs:
                return {"year": year, "is_real": True, "activity": real_contribs}
        except Exception as e:
            import logging

            logging.getLogger(__name__).error(
                f"Failed to fetch contributions for year {year}: {e}"
            )

    # Mock data for that year (e.g. 365 values)
    from datetime import datetime, timedelta

    activity_values = []
    import calendar

    is_leap = calendar.isleap(year)
    days_in_year = 366 if is_leap else 365
    start_date = datetime(year, 1, 1)
    random.seed(year)
    for i in range(days_in_year):
        date_str = (start_date + timedelta(days=i)).strftime("%Y-%m-%d")
        activity_values.append(
            {"date": date_str, "count": random.choice([0, 0, 0, 1, 2, 4, 8, 0])}
        )
    return {"year": year, "is_real": False, "activity": activity_values}


@router.get("/day-activity")
async def github_day_activity(
    date: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    from app.models.entities import GithubProfile

    stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
    profile = db.scalar(stmt)
    if not profile or not profile.access_token:
        return {
            "date": date,
            "has_real_data": False,
            "summary": "Connect your GitHub account to see real daily contribution details here.",
            "details": [],
        }

    from_date = f"{date}T00:00:00Z"
    to_date = f"{date}T23:59:59Z"

    url = "https://api.github.com/graphql"
    headers = {
        "Authorization": f"bearer {profile.access_token}",
        "User-Agent": "DevMentor-App",
    }

    query = """
    query($username: String!, $from: DateTime!, $to: DateTime!) {
      user(login: $username) {
        contributionsCollection(from: $from, to: $to) {
          commitContributionsByRepository {
            repository {
              nameWithOwner
            }
            contributions {
              totalCount
            }
          }
          pullRequestContributionsByRepository {
            repository {
              nameWithOwner
            }
            contributions {
              totalCount
            }
          }
          issueContributionsByRepository {
            repository {
              nameWithOwner
            }
            contributions {
              totalCount
            }
          }
          pullRequestReviewContributionsByRepository {
            repository {
              nameWithOwner
            }
            contributions {
              totalCount
            }
          }
        }
      }
    }
    """

    variables = {"username": profile.login, "from": from_date, "to": to_date}

    import httpx

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                url,
                json={"query": query, "variables": variables},
                headers=headers,
                timeout=15.0,
            )
            if response.status_code == 200:
                data = response.json()
                collection = (
                    data.get("data", {})
                    .get("user", {})
                    .get("contributionsCollection", {})
                )
                if collection is None:
                    collection = {}

                details = []

                # Commits
                for item in collection.get("commitContributionsByRepository", []):
                    repo_name = item.get("repository", {}).get("nameWithOwner")
                    count = item.get("contributions", {}).get("totalCount", 0)
                    if count > 0:
                        details.append(
                            f"Committed {count} time{'' if count == 1 else 's'} to {repo_name}"
                        )

                # Pull Requests
                for item in collection.get("pullRequestContributionsByRepository", []):
                    repo_name = item.get("repository", {}).get("nameWithOwner")
                    count = item.get("contributions", {}).get("totalCount", 0)
                    if count > 0:
                        details.append(
                            f"Opened {count} pull request{'' if count == 1 else 's'} in {repo_name}"
                        )

                # Issues
                for item in collection.get("issueContributionsByRepository", []):
                    repo_name = item.get("repository", {}).get("nameWithOwner")
                    count = item.get("contributions", {}).get("totalCount", 0)
                    if count > 0:
                        details.append(
                            f"Opened {count} issue{'' if count == 1 else 's'} in {repo_name}"
                        )

                # Reviews
                for item in collection.get(
                    "pullRequestReviewContributionsByRepository", []
                ):
                    repo_name = item.get("repository", {}).get("nameWithOwner")
                    count = item.get("contributions", {}).get("totalCount", 0)
                    if count > 0:
                        details.append(
                            f"Reviewed {count} pull request{'' if count == 1 else 's'} in {repo_name}"
                        )

                summary = (
                    f"Activity on {date}:"
                    if details
                    else f"No contributions found on {date}."
                )
                return {
                    "date": date,
                    "has_real_data": True,
                    "summary": summary,
                    "details": details,
                }
        except Exception as e:
            import logging

            logging.getLogger(__name__).error(f"Error fetching day activity: {e}")

    return {
        "date": date,
        "has_real_data": False,
        "summary": f"Failed to fetch real-time activity for {date}.",
        "details": [],
    }
