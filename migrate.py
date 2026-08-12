import os
import re

files = [
    r"c:\company\truthworld\lib\features\channel\presentation\controllers\channel_controller_unified.dart",
    r"c:\company\truthworld\lib\features\channel\presentation\controllers\channel_subscription_controller.dart",
    r"c:\company\truthworld\lib\features\admin\presentation\controllers\admin_controller.dart",
    r"c:\company\truthworld\lib\features\admin\presentation\controllers\admin_video_player_controller.dart",
    r"c:\company\truthworld\lib\features\advertiser\presentation\controllers\advertiser_portal_controller.dart",
    r"c:\company\truthworld\lib\features\community\community_post_upload_controller.dart",
    r"c:\company\truthworld\lib\features\community\presentation\controllers\community_post_controller.dart",
    r"c:\company\truthworld\lib\features\community\presentation\controllers\saved_comments_controller.dart",
    r"c:\company\truthworld\lib\features\community\presentation\controllers\saved_community_posts_controller.dart",
    r"c:\company\truthworld\lib\features\analytics\presentation\controllers\creator_analytics_controller.dart",
]

def wrap_listen(content):
    # Match variables assigned to .listen()
    # e.g. _sub = stream.listen(...) -> trackSubscription(_sub = stream.listen(...))
    # We have to be careful with multi-line.
    # Instead of regex over the whole .listen(), we can just prefix `trackSubscription(` and append `)` at the end of the statement.
    # Better: just use regex for standard patterns.
    # Find all `.listen(` occurrences. Trace back to the assignment.
    # It's easier to find `_sub = ...listen(` and replace.
    # We can split by semicolon.
    statements = content.split(';')
    for i in range(len(statements)):
        stmt = statements[i]
        if ".listen(" in stmt and "trackSubscription(" not in stmt:
            # Check if it's an assignment
            match = re.search(r"(\b\w+\s*=)\s*(.*\.listen\([^;]*)", stmt, flags=re.DOTALL)
            if match:
                statements[i] = stmt[:match.start()] + "trackSubscription(" + match.group(1) + " " + match.group(2) + ")" + stmt[match.end():]
            elif re.search(r"^\s*.*\.listen\([^;]*", stmt, flags=re.DOTALL):
                # not an assignment, just .listen
                # trackSubscription(stream.listen(...))
                match2 = re.search(r"([^\s=]+.*\.listen\([^;]*)", stmt, flags=re.DOTALL)
                if match2:
                    statements[i] = stmt[:match2.start()] + "trackSubscription(" + match2.group(1) + ")" + stmt[match2.end():]
                    
        # Timer
        if "Timer.periodic(" in stmt and "trackTimer(" not in stmt:
            match = re.search(r"(\b\w+\s*=)\s*(Timer\.periodic\([^;]*)", stmt, flags=re.DOTALL)
            if match:
                statements[i] = stmt[:match.start()] + "trackTimer(" + match.group(1) + " " + match.group(2) + ")" + stmt[match.end():]
        elif "Timer(" in stmt and "trackTimer(" not in stmt and "Timer.periodic(" not in stmt:
            match = re.search(r"(\b\w+\s*=)\s*(Timer\([^;]*)", stmt, flags=re.DOTALL)
            if match:
                statements[i] = stmt[:match.start()] + "trackTimer(" + match.group(1) + " " + match.group(2) + ")" + stmt[match.end():]

        # ScrollController
        if "ScrollController(" in stmt and "trackScrollController(" not in stmt:
            match = re.search(r"(\b\w+\s*=)\s*(ScrollController\([^;]*)", stmt, flags=re.DOTALL)
            if match:
                statements[i] = stmt[:match.start()] + "trackScrollController(" + match.group(1) + " " + match.group(2) + ")" + stmt[match.end():]

        # TextEditingController
        if "TextEditingController(" in stmt and "trackTextController(" not in stmt:
            match = re.search(r"(\b\w+\s*=)\s*(TextEditingController\([^;]*)", stmt, flags=re.DOTALL)
            if match:
                statements[i] = stmt[:match.start()] + "trackTextController(" + match.group(1) + " " + match.group(2) + ")" + stmt[match.end():]

    return ";".join(statements)

def remove_onclose_cancels(content):
    # Find onClose method
    match = re.search(r"void\s+onClose\s*\(\)\s*\{([\s\S]*?)\}", content)
    if not match:
        return content
    
    body = match.group(1)
    # Remove lines with .cancel() or .dispose() from body
    lines = body.split("\n")
    new_lines = []
    for line in lines:
        if ".cancel()" in line or ".dispose()" in line:
            # Check if it's safe to remove
            if re.search(r"\b\w+\.(cancel|dispose)\(\)", line):
                continue
        new_lines.append(line)
    
    new_body = "\n".join(new_lines)
    
    # if only super.onClose() is left
    clean_body = re.sub(r"//.*", "", new_body).strip()
    clean_body = re.sub(r"\s+", "", clean_body)
    if clean_body == "super.onClose();" or clean_body == "":
        # remove entire onClose
        # Replace the entire function with empty string
        # Need to match the `@override` if present
        content = re.sub(r"(@override\s+)?void\s+onClose\s*\(\)\s*\{[\s\S]*?\}", "", content)
    else:
        content = content.replace(match.group(1), new_body)
    
    return content

def process():
    for filepath in files:
        if not os.path.exists(filepath):
            continue
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
            
        original_content = content
        
        content = wrap_listen(content)
        content = remove_onclose_cancels(content)
        
        if "extends GetxController" in content:
            content = content.replace("extends GetxController", "extends BaseController")
            if "package:truthworld/core/base/base_controller.dart" not in content:
                content = "import 'package:truthworld/core/base/base_controller.dart';\n" + content

        if content != original_content:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Modified: {filepath}")

process()
