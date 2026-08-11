import os

file_path = 'lib/screens/repositories/discover_repos_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace("import '../../providers/app_state.dart';", "import '../../providers/app_state.dart';\nimport '../../widgets/tatvik_loader.dart';")
content = content.replace("AI Resume Reviewer", "Tatvik Resume Reviewer")
content = content.replace("AI Project Evaluator", "Tatvik Project Evaluator")
content = content.replace("AI Developer Tools", "Tatvik Intelligence")
content = content.replace("AI MENTOR", "TATVIK")
content = content.replace("Center(child: CircularProgressIndicator())", "TatvikLoader()")
content = content.replace("const Center(child: CircularProgressIndicator())", "const TatvikLoader()")

with open(file_path, 'w') as f:
    f.write(content)

# Update main nav screen Walkthrough text
file_path2 = 'lib/screens/main_navigation_screen.dart'
with open(file_path2, 'r') as f:
    content2 = f.read()

content2 = content2.replace("AI Mentor Chat", "Tatvik Chat")
content2 = content2.replace("AI Insights", "Tatvik Insights")
with open(file_path2, 'w') as f:
    f.write(content2)

print("Replacements done.")
