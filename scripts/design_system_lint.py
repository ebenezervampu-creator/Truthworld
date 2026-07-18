#!/usr/bin/env python3
import os
import re
import sys

# Paths to ignore
IGNORE_PATHS = [
    os.path.join('lib', 'theme'),
    os.path.join('lib', 'generated'),
]

# Regex patterns
COLOR_REGEX = re.compile(r'\bColor\s*\((0x[0-9a-fA-F]+|\d+)\)')
RADIUS_REGEX = re.compile(r'\bBorderRadius\.circular\s*\(\s*(\d+)(?:\.0)?\s*\)')
EDGE_INSETS_REGEX = re.compile(r'\bEdgeInsets\.(all|symmetric|only|fromLTRB)\s*\(')
DURATION_REGEX = re.compile(r'\bDuration\s*\(')

# Help mappings for suggestions
COLOR_SUGGESTIONS = {
    '0xFF9B30FF': 'context.colors.brand',
    '0xFF5C1B9F': 'context.colors.brandVariant',
    '0xFF2D1060': 'context.colors.brandContainer',
    '0xFF0F0F0F': 'context.colors.background',
    '0xFF212121': 'context.colors.surface',
    '0xFF272727': 'context.colors.surfaceContainer',
    '0xFF2E2E2E': 'context.colors.surfaceContainerHigh',
    '0xFF3F3F3F': 'context.colors.surfaceContainerHighest',
    '0xFF121212': 'context.colors.surfaceInput',
    '0xFF161618': 'context.colors.appBarSurface',
    '0xFFEF4444': 'context.colors.error',
    '0xFFFF6B6B': 'context.colors.error (standardized to EF4444)',
    '0xFF10B981': 'context.colors.success',
    '0xFFF59E0B': 'context.colors.warning',
    '0xFF3B82F6': 'context.colors.info',
}

def check_file(filepath):
    errors = []
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        try:
            lines = f.readlines()
        except Exception:
            return errors
            
    for line_idx, line in enumerate(lines, 1):
        stripped = line.strip()
        # Skip import lines and comments
        if stripped.startswith('import ') or stripped.startswith('//') or stripped.startswith('*') or stripped.startswith('///'):
            continue
            
        # 1. Colors
        for match in COLOR_REGEX.finditer(line):
            hex_val = match.group(1).upper()
            # If it's a short 0x value, pad it
            if hex_val.startswith('0X') and len(hex_val) < 10:
                continue
            
            # Map specific hexes to exact suggestions if we know them
            match_hex = hex_val.replace('0X', '0xFF') if hex_val.startswith('0X') else hex_val
            suggestion = COLOR_SUGGESTIONS.get(match_hex, 'context.colors.<semanticRole>')
            
            errors.append({
                'line': line_idx,
                'found': match.group(0),
                'rule': 'Raw Color(...) instantiation is forbidden outside lib/theme/.',
                'suggestion': f'Use semantic colors instead: `{suggestion}` or `Theme.of(context).colorScheme.<role>`.'
            })
            
        # 2. Border Radius
        for match in RADIUS_REGEX.finditer(line):
            val = int(match.group(1))
            # Permitted exceptions: 0 (no radius) and 999/9999 (pills/circles)
            if val in [0, 999, 9999]:
                continue
                
            suggestion = 'context.radius.<size>'
            if val <= 4:
                suggestion = 'context.radius.sm'
            elif val <= 8:
                suggestion = 'context.radius.md'
            elif val <= 12:
                suggestion = 'context.radius.lg'
            elif val <= 16:
                suggestion = 'context.radius.xl'
                
            errors.append({
                'line': line_idx,
                'found': match.group(0),
                'rule': 'Raw BorderRadius.circular(...) is discouraged.',
                'suggestion': f'Use semantic radius tokens: `{suggestion}` (permitted exceptions: 0, 999 for pills).'
            })
            
        # 3. EdgeInsets
        for match in EDGE_INSETS_REGEX.finditer(line):
            # Check for allowed exceptions inside the line (e.g. zero values)
            if 'EdgeInsets.zero' in line:
                continue
            
            kind = match.group(1)
            suggestion = 'context.insets.<size>'
            if kind == 'all':
                # Try to extract the padding value
                val_match = re.search(r'all\s*\(\s*(\d+)(?:\.0)?\s*\)', line)
                if val_match:
                    val = int(val_match.group(1))
                    if val == 0:
                        continue # Allowed exception
                    # Map common values
                    if val == 4:
                        suggestion = 'context.insets.xs'
                    elif val == 8:
                        suggestion = 'context.insets.sm'
                    elif val == 16:
                        suggestion = 'context.insets.md'
                    elif val == 24:
                        suggestion = 'context.insets.lg'
                        
            errors.append({
                'line': line_idx,
                'found': match.group(0),
                'rule': 'Raw EdgeInsets construction is discouraged.',
                'suggestion': f'Use semantic insets: `{suggestion}` (e.g. `context.insets.md` or `context.insets.md.horizontal`). For page/layout margins, use `context.layoutSpacing`.'
            })
            
        # 4. Duration
        for match in DURATION_REGEX.finditer(line):
            # Allowed exceptions: zero and tests/mocks
            if 'Duration.zero' in line or 'Duration(milliseconds: 1)' in line:
                continue
                
            errors.append({
                'line': line_idx,
                'found': match.group(0),
                'rule': 'Raw Duration(...) instantiation is discouraged.',
                'suggestion': 'Use semantic motion tokens: `context.motion.normal`, `context.motion.fast`, or `context.motion.slow`.'
            })
            
    return errors

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lib_dir = os.path.join(root_dir, 'lib')
    
    if not os.path.exists(lib_dir):
        print(f"Error: Could not find lib directory at {lib_dir}")
        sys.exit(1)
        
    total_violations = 0
    scanned_files = 0
    
    print("=" * 80)
    print("TRUTHWORLD DESIGN SYSTEM COMPLIANCE LINTER")
    print("=" * 80)
    
    for root, dirs, files in os.walk(lib_dir):
        # Apply path exclusions
        relative_root = os.path.relpath(root, root_dir)
        if any(relative_root.startswith(ignore_path) for ignore_path in IGNORE_PATHS):
            continue
            
        for file in files:
            if not file.endswith('.dart'):
                continue
                
            filepath = os.path.join(root, file)
            file_errors = check_file(filepath)
            
            if file_errors:
                scanned_files += 1
                total_violations += len(file_errors)
                print(f"\n[VIOLATION] {os.path.relpath(filepath, root_dir)}")
                for err in file_errors:
                    print(f"  Line {err['line']}: Found `{err['found']}`")
                    print(f"    Rule: {err['rule']}")
                    print(f"    Suggestion: {err['suggestion']}")
                    
    print("\n" + "=" * 80)
    print("LINT REPORT SUMMARY")
    print("=" * 80)
    print(f"Total non-compliant files: {scanned_files}")
    print(f"Total violations found:    {total_violations}")
    print("=" * 80)
    
    # We exit with 0 during initial migration so CI doesn't block immediately,
    # but print a clear warning if violations exist.
    if total_violations > 0:
        print("Warning: Please refactor above files to use semantic design tokens.")
        
if __name__ == '__main__':
    main()
