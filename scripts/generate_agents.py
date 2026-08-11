import os

agents = [
    ("Scout", "scout.py", "Discovers information."),
    ("Scholar", "scholar.py", "Reads and summarizes."),
    ("Architect", "architect.py", "Builds relationships."),
    ("Reviewer", "reviewer.py", "Detects duplicates and verifies quality."),
    ("Mentor", "mentor.py", "Explains concepts."),
    ("Career", "career.py", "Maps technologies to career opportunities."),
    ("Trend", "trend.py", "Predicts future technologies."),
    ("Guardian", "guardian.py", "Monitors security advisories."),
    ("Navigator", "navigator.py", "Builds personalized recommendations."),
    ("Memory", "memory.py", "Uses Cognee to remember knowledge.")
]

template = """from typing import Any, Dict
from backend.app.tatvik.agents.base import TatvikAgent

class {class_name}Agent(TatvikAgent):
    @property
    def name(self) -> str:
        return "{name}"

    @property
    def responsibility(self) -> str:
        return "{responsibility}"

    async def process(self, context: Dict[str, Any], payload: Any) -> Any:
        # Implementation for {name}
        pass
"""

agent_dir = "/home/heet18/Projects/tatvik/backend/app/tatvik/agents"

for name, filename, resp in agents:
    filepath = os.path.join(agent_dir, filename)
    with open(filepath, "w") as f:
        f.write(template.format(class_name=name, name=name, responsibility=resp))

print("Agent stubs created successfully.")
