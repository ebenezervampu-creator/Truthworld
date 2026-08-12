import os
import re

files = [
    'custom_play.dart', 'video_controller.dart', 'tower_player_controller.dart',
    'upload_controller.dart', 'custom_controller.dart', 'comments_controller.dart',
    'adaptive_birate_controller.dart', 'audio_only_service.dart',
    'comment_input_controller.dart', 'reply_input_controller.dart',
    'download_videoplayer.dart', 'player_lock_controller.dart',
    'video_analytics_controller.dart'
]

base_dir = r'c:\company\truthworld\lib\features\video\presentation\controllers'

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        original = f.read()
    
    content = original
    
    # 1. Extends GetxController -> BaseController
    if 'extends GetxController' in content:
        content = content.replace('extends GetxController', 'extends BaseController')
        if 'package:truthworld/core/base/base_controller.dart' not in content:
            content = re.sub(r"(import '.*?';)", r"\1\nimport 'package:truthworld/core/base/base_controller.dart';", content, count=1)
            
    # 2. Wrapping TextEditingController
    def text_repl(m):
        prefix = m.group(1)
        if 'late ' not in prefix and ('final ' in prefix or 'var ' in prefix):
            prefix = prefix.replace('final ', 'late final ').replace('var ', 'late var ')
        var_name = m.group(2)
        return f"{prefix}{var_name} = trackTextController(TextEditingController({m.group(3)}));"
    
    content = re.sub(r'([ \t]*(?:late\s+)?(?:final\s+|var\s+)?(?:TextEditingController\s+)?\s+)(\w+)\s*=\s*TextEditingController\((.*?)\);', text_repl, content)

    # 3. Wrapping ScrollController
    def scroll_repl(m):
        prefix = m.group(1)
        if 'late ' not in prefix and ('final ' in prefix or 'var ' in prefix):
            prefix = prefix.replace('final ', 'late final ').replace('var ', 'late var ')
        var_name = m.group(2)
        return f"{prefix}{var_name} = trackScrollController(ScrollController({m.group(3)}));"
        
    content = re.sub(r'([ \t]*(?:late\s+)?(?:final\s+|var\s+)?(?:ScrollController\s+)?\s+)(\w+)\s*=\s*ScrollController\((.*?)\);', scroll_repl, content)

    # 4. Wrap Timer(...) and Timer.periodic(...)
    # e.g., _timer = Timer(...) -> trackTimer(_timer = Timer(...))
    # We will search for assignments to variables:
    # \w+\s*=\s*Timer(?:\.periodic)?\(.*?\)
    # but that might span multiple lines. We can use a regex that handles assignments.
    
    def timer_repl(m):
        var_part = m.group(1)
        timer_call = m.group(2)
        # Avoid double-wrapping
        if 'trackTimer' in var_part: return m.group(0)
        return f"trackTimer({var_part}{timer_call})"

    # matches var = Timer(...) or var = Timer.periodic(...) where timer might span lines
    # To correctly balance parentheses, it's a bit tricky in regex.
    # Let's just do single-line ones first or simple ones.
    content = re.sub(r'([ \t]*(?:this\.)?\w+\s*=\s*)(Timer(?:\.periodic)?\([^;]+);', timer_repl, content)

    # 5. Wrap .listen(...)
    # e.g., _sub = stream.listen(...) -> trackSubscription(_sub = stream.listen(...))
    def listen_repl(m):
        var_part = m.group(1)
        listen_call = m.group(2)
        if 'trackSubscription' in var_part: return m.group(0)
        return f"trackSubscription({var_part}{listen_call})"
    
    content = re.sub(r'([ \t]*(?:this\.)?\w+\s*=\s*)([^;=]+\.listen\([^;]+);', listen_repl, content)
    
    # 6. Remove cancellations in onClose()
    # We will find the onClose() block and remove .cancel() and .dispose() for these types
    def onclose_repl(m):
        block = m.group(2)
        # We need to remove things like `xxx.cancel();`, `xxx?.cancel();`, `xxx.dispose();`, `xxx?.dispose();`
        # But wait, ONLY for StreamSubscription, Timer, ScrollController, TextEditingController.
        # It's hard to know types. The user said: "Remove the corresponding manual .cancel()/.dispose() calls from onClose() ONLY"
        # Since I wrapped them, I can remove all `_timer?.cancel();`, `_subscription?.cancel();` etc.
        # Let's remove any `.cancel();` and `.dispose();` lines from onClose
        # Actually, maybe it's safer to remove specific names if we collected them.
        
        # Let's just blindly remove `.cancel()` and `.dispose()` for variables that match typical naming
        # or just all of them since we are replacing all of these types!
        # "Remove the corresponding manual .cancel()/.dispose() calls"
        lines = block.split('\n')
        new_lines = []
        for line in lines:
            if re.search(r'\b(cancel|dispose)\(\)\s*;', line):
                # Check if it's a known tracked type by name conventions, or just remove
                if any(x in line.lower() for x in ['timer', 'sub', 'listen', 'scroll', 'text', 'controller', 'player']):
                    # wait, player.dispose() shouldn't be removed if it's not Scroll/Text controller!
                    # What if it's a VideoPlayerController? It says "ALL TextEditingController/ScrollController"
                    if 'VideoPlayerController' in original and 'dispose' in line and not ('text' in line.lower() or 'scroll' in line.lower() or 'comment' in line.lower()):
                        new_lines.append(line)
                        continue
                else:
                    # just keep it if it doesn't look like a standard tracked thing?
                    pass
                # wait, let's keep all dispose/cancels except the ones we're sure of?
                # Actually, the user says "Remove the corresponding manual .cancel()/.dispose() calls".
                # I'll let python remove them, but I will review.
                # It's safer to use python to do the track*() wrappers, and manually fix onClose!
                new_lines.append(line)
            else:
                new_lines.append(line)
        
        new_block = '\n'.join(new_lines)
        if new_block.strip() == 'super.onClose();':
            return ''
        return m.group(1) + new_block + m.group(3)

    # we will manually fix onClose() to be safe.
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Updated {os.path.basename(filepath)}')

for f in files:
    p = os.path.join(base_dir, f)
    if os.path.exists(p):
        process_file(p)
