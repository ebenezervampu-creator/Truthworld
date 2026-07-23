import os
import re
import sys
import argparse

LIB_DIR = r"c:\company\truthworld\lib"

# Patterns for forbidden hardcoded constructs
FORBIDDEN_PATTERNS = {
    'Colors.*': re.compile(r'\bColors\.[a-zA-Z0-9_]+'),
    'GoogleFonts.*': re.compile(r'\bGoogleFonts\.[a-zA-Z0-9_]+'),
    'Raw TextStyle': re.compile(r'\bTextStyle\s*\('),
    'FontWeight.*': re.compile(r'\bFontWeight\.[a-zA-Z0-9_]+'),
    'BorderRadius.*': re.compile(r'\bBorderRadius\.(circular|all|only)\b'),
    'EdgeInsets.*': re.compile(r'\bEdgeInsets\.(all|symmetric|only|fromLTRB)\b'),
    'SizedBox layout': re.compile(r'\bSizedBox\s*\(\s*(height|width)\s*:'),
    'Hardcoded Duration': re.compile(r'\bDuration\s*\(\s*(milliseconds|seconds)\s*:'),
}

def scan_file(filepath):
    rel_path = os.path.relpath(filepath, LIB_DIR).replace('\\', '/')
    
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
        content = ''.join(lines)
    
    # Ignore theme definition files themselves
    if rel_path.startswith('theme/'):
        return None
    
    is_widget_file = any(kw in rel_path for kw in ['page', 'screen', 'view', 'tab', 'widget', 'components']) or ('Widget build(' in content)
    if not is_widget_file:
        return None
        
    violations = {}
    total_violations = 0
    
    for line_idx, line in enumerate(lines, start=1):
        # Ignore comments
        stripped = line.strip()
        if stripped.startswith('//') or stripped.startswith('*') or stripped.startswith('/*'):
            continue
            
        for name, pattern in FORBIDDEN_PATTERNS.items():
            matches = pattern.findall(line)
            if matches:
                if name not in violations:
                    violations[name] = 0
                violations[name] += len(matches)
                total_violations += len(matches)
                
    has_app_theme = 'app_theme.dart' in content or 'AppTheme' in content
    
    return {
        'path': rel_path,
        'has_app_theme': has_app_theme,
        'violations': violations,
        'total_violations': total_violations
    }

def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')

    parser = argparse.ArgumentParser(description="TruthWorld Design System Linter")
    parser.add_argument('--fail-below', type=float, default=0.0, help="Fail build if compliance percentage is below threshold")
    args = parser.parse_args()

    scanned_files = []
    
    for root, _, files in os.walk(LIB_DIR):
        for f in files:
            if f.endswith('.dart'):
                filepath = os.path.join(root, f)
                res = scan_file(filepath)
                if res:
                    scanned_files.append(res)
                    
    total_files = len(scanned_files)
    compliant_files = [f for f in scanned_files if f['total_violations'] == 0 and f['has_app_theme']]
    compliance_score = (len(compliant_files) / total_files * 100.0) if total_files > 0 else 100.0
    
    print("==========================================================================")
    print(" TRUTHWORLD DESIGN SYSTEM COMPLIANCE REPORT")
    print("==========================================================================")
    print(f"Total UI Files Scanned  : {total_files}")
    print(f"Fully Compliant Files   : {len(compliant_files)}")
    print(f"Overall Compliance Score: {compliance_score:.1f}%\n")
    
    non_compliant = [f for f in scanned_files if f['total_violations'] > 0 or not f['has_app_theme']]
    non_compliant.sort(key=lambda x: x['total_violations'], reverse=True)
    
    if non_compliant:
        print("Top Non-Compliant Files:")
        for f in non_compliant[:20]:
            print(f"\n[X] {f['path']} (Total Violations: {f['total_violations']}, AppTheme: {f['has_app_theme']})")
            for v_name, v_count in f['violations'].items():
                print(f"    - {v_name}: {v_count}")
    else:
        print("100% PERFECT DESIGN SYSTEM ADOPTION ACHIEVED!")
        
    print("==========================================================================")
    
    if compliance_score < args.fail_below:
        print(f"ERROR: Compliance score {compliance_score:.1f}% is below required threshold {args.fail_below:.1f}%")
        sys.exit(1)

if __name__ == '__main__':
    main()
