import logging
from datetime import datetime
import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.entities import GithubProfile, Repository, DeveloperScore

logger = logging.getLogger(__name__)


class GithubService:
    def __init__(self, db: Session):
        self.db = db

    async def sync_user_github_data(self, user_id: str, access_token: str) -> dict:
        """
        Syncs GitHub profile data and repositories for a given user.
        """
        async with httpx.AsyncClient() as client:
            # 1. Fetch GitHub profile
            profile_response = await client.get(
                "https://api.github.com/user",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            if profile_response.status_code != 200:
                raise ValueError(
                    f"Failed to fetch GitHub profile: {profile_response.text}"
                )

            github_data = profile_response.json()
            login = github_data.get("login")
            avatar_url = github_data.get("avatar_url")
            name = github_data.get("name") or login

            # Update User profile details
            user_stmt = select(User).where(User.id == user_id)
            user = self.db.scalar(user_stmt)
            if user:
                user.avatar_url = avatar_url
                user.username = login
                self.db.add(user)

            # Upsert GithubProfile
            profile_stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
            profile = self.db.scalar(profile_stmt)
            if not profile:
                profile = GithubProfile(user_id=user_id, login=login)

            profile.access_token = access_token
            profile.synced_at = datetime.utcnow()
            self.db.add(profile)

            # 2. Fetch User's Repositories
            repos_response = await client.get(
                "https://api.github.com/user/repos?per_page=100",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            if repos_response.status_code != 200:
                raise ValueError(
                    f"Failed to fetch GitHub repositories: {repos_response.text}"
                )

            repos_data = repos_response.json()

            # Fetch total commits using Search Commits API
            total_commits = 0
            try:
                commits_response = await client.get(
                    f"https://api.github.com/search/commits?q=author:{login}",
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Accept": "application/vnd.github.v3+json",
                    },
                    timeout=8.0,
                )
                if commits_response.status_code == 200:
                    total_commits = commits_response.json().get("total_count", 0)
            except Exception as ce:
                logger.warning(f"Failed to fetch total commits for user {login}: {ce}")

            # Fetch existing repositories for the user to avoid duplicate key issues or delete and recreate
            # Delete existing repos for clean sync to avoid primary key/unique issues on full_name across users
            existing_repos_stmt = select(Repository).where(
                Repository.user_id == user_id
            )
            existing_repos = self.db.scalars(existing_repos_stmt).all()
            for r in existing_repos:
                self.db.delete(r)

            total_stars = 0
            synced_repos = []

            for r_data in repos_data:
                owner = r_data.get("owner", {}).get("login", "")
                name = r_data.get("name", "")
                full_name = r_data.get("full_name", f"{owner}/{name}")
                description = r_data.get("description") or "No description provided."
                language = r_data.get("language")
                stars = r_data.get("stargazers_count", 0)
                forks = r_data.get("forks_count", 0)
                watchers = r_data.get("watchers_count", 0)
                open_issues = r_data.get("open_issues_count", 0)

                total_stars += stars

                difficulty = "Beginner"
                if stars > 50:
                    difficulty = "Advanced"
                elif stars > 5:
                    difficulty = "Intermediate"

                impact_score = min(max(stars * 5 + 40, 40), 100)

                repo = Repository(
                    user_id=user_id,
                    full_name=full_name,
                    owner=owner,
                    name=name,
                    description=description,
                    language=language,
                    difficulty=difficulty,
                    impact_score=impact_score,
                    why_recommended="Based on your GitHub activity and repository engagement.",
                    stars_count=stars,
                    forks_count=forks,
                    watchers_count=watchers,
                    open_issues_count=open_issues,
                    synced_at=datetime.utcnow(),
                )
                self.db.add(repo)
                synced_repos.append(
                    {
                        "name": name,
                        "owner": owner,
                        "description": description,
                        "difficulty": difficulty,
                        "impactScore": impact_score,
                        "tags": [language] if language else ["Repo"],
                        "whyRecommended": repo.why_recommended,
                    }
                )

            # Calculate a basic Developer Score and save it
            # Developer score formula (0 to 10 scale) using commits count
            developer_score_val = round(
                min(
                    max(
                        total_stars * 0.2
                        + len(repos_data) * 0.3
                        + total_commits * 0.01
                        + 3.0,
                        1.0,
                    ),
                    10.0,
                ),
                1,
            )

            score_stmt = select(DeveloperScore).where(DeveloperScore.user_id == user_id)
            score_rec = self.db.scalar(score_stmt)
            if not score_rec:
                score_rec = DeveloperScore(user_id=user_id)
            score_rec.score = int(developer_score_val * 10)  # scale to 0-100 in db
            score_rec.calculated_at = datetime.utcnow()
            self.db.add(score_rec)

            self.db.commit()

            return {
                "login": login,
                "avatar_url": avatar_url,
                "repos_count": len(repos_data),
                "total_stars": total_stars,
                "developer_score": developer_score_val,
            }

    async def sync_public_github_data(self, user_id: str, username: str) -> dict:
        """
        Syncs GitHub profile data and repositories for a given user using public GitHub API (no OAuth token needed).
        """
        async with httpx.AsyncClient() as client:
            headers = {"User-Agent": "DevMentor-App"}

            # 1. Fetch GitHub profile
            profile_response = await client.get(
                f"https://api.github.com/users/{username}", headers=headers
            )
            if profile_response.status_code != 200:
                raise ValueError(
                    f"Failed to fetch GitHub profile for {username}: {profile_response.text}"
                )

            github_data = profile_response.json()
            login = github_data.get("login", username)
            avatar_url = github_data.get("avatar_url")
            name = github_data.get("name") or login

            # Update User profile details in DB
            user_stmt = select(User).where(User.id == user_id)
            user = self.db.scalar(user_stmt)
            if user:
                user.avatar_url = avatar_url
                user.username = login
                self.db.add(user)

            # Upsert GithubProfile without access token
            profile_stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
            profile = self.db.scalar(profile_stmt)
            if not profile:
                profile = GithubProfile(user_id=user_id, login=login)

            profile.synced_at = datetime.utcnow()
            self.db.add(profile)

            # 2. Fetch User's Repositories
            repos_response = await client.get(
                f"https://api.github.com/users/{username}/repos?per_page=100",
                headers=headers,
            )
            if repos_response.status_code != 200:
                raise ValueError(
                    f"Failed to fetch GitHub repositories for {username}: {repos_response.text}"
                )

            repos_data = repos_response.json()

            # Fetch total commits using Search Commits API
            total_commits = 0
            try:
                commits_response = await client.get(
                    f"https://api.github.com/search/commits?q=author:{login}",
                    headers={
                        "Accept": "application/vnd.github.v3+json",
                        "User-Agent": "DevMentor-App",
                    },
                    timeout=8.0,
                )
                if commits_response.status_code == 200:
                    total_commits = commits_response.json().get("total_count", 0)
            except Exception as ce:
                logger.warning(f"Failed to fetch total commits for user {login}: {ce}")

            # Delete existing repos for clean sync
            existing_repos_stmt = select(Repository).where(
                Repository.user_id == user_id
            )
            existing_repos = self.db.scalars(existing_repos_stmt).all()
            for r in existing_repos:
                self.db.delete(r)

            total_stars = 0
            synced_repos = []

            for r_data in repos_data:
                owner = r_data.get("owner", {}).get("login", login)
                repo_name = r_data.get("name", "")
                full_name = r_data.get("full_name", f"{owner}/{repo_name}")
                description = r_data.get("description") or "No description provided."
                language = r_data.get("language")
                stars = r_data.get("stargazers_count", 0)
                forks = r_data.get("forks_count", 0)
                watchers = r_data.get("watchers_count", 0)
                open_issues = r_data.get("open_issues_count", 0)

                total_stars += stars

                difficulty = "Beginner"
                if stars > 50:
                    difficulty = "Advanced"
                elif stars > 5:
                    difficulty = "Intermediate"

                impact_score = min(max(stars * 5 + 40, 40), 100)

                repo = Repository(
                    user_id=user_id,
                    full_name=full_name,
                    owner=owner,
                    name=repo_name,
                    description=description,
                    language=language,
                    difficulty=difficulty,
                    impact_score=impact_score,
                    why_recommended="Based on your GitHub activity and repository engagement.",
                    stars_count=stars,
                    forks_count=forks,
                    watchers_count=watchers,
                    open_issues_count=open_issues,
                    synced_at=datetime.utcnow(),
                )
                self.db.add(repo)
                synced_repos.append(
                    {
                        "name": repo_name,
                        "owner": owner,
                        "description": description,
                        "difficulty": difficulty,
                        "impactScore": impact_score,
                        "tags": [language] if language else ["Repo"],
                        "whyRecommended": repo.why_recommended,
                    }
                )

            # Calculate a basic Developer Score and save it using commits count
            developer_score_val = round(
                min(
                    max(
                        total_stars * 0.2
                        + len(repos_data) * 0.3
                        + total_commits * 0.01
                        + 3.0,
                        1.0,
                    ),
                    10.0,
                ),
                1,
            )

            score_stmt = select(DeveloperScore).where(DeveloperScore.user_id == user_id)
            score_rec = self.db.scalar(score_stmt)
            if not score_rec:
                score_rec = DeveloperScore(user_id=user_id)
            score_rec.score = int(developer_score_val * 10)  # scale to 0-100 in db
            score_rec.calculated_at = datetime.utcnow()
            self.db.add(score_rec)

            self.db.commit()

            return {
                "login": login,
                "repos_count": len(repos_data),
                "total_stars": total_stars,
                "total_commits": total_commits,
                "developer_score": developer_score_val,
            }
