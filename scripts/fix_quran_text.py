#!/usr/bin/env python3
"""
Fetch correct Uthmani Quran text from quran.com API and update local data.
Fixes missing spaces between words that cause display issues.
"""

import json
import sys
import urllib.request
import time

def fetch_surah(surah_num, max_retries=3):
    """Fetch all verses for a surah from quran.com API."""
    url = f"https://api.quran.com/api/v4/verses/by_chapter/{surah_num}?language=en&words=false&per_page=250&fields=text_uthmani"
    
    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(url, headers={
                'User-Agent': 'QuranApp/1.0'
            })
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                return data.get('verses', [])
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(1)
            else:
                print(f"  ERROR fetching surah {surah_num}: {e}", file=sys.stderr)
                return []

def main():
    sys.stdout.reconfigure(encoding='utf-8')
    
    # Load current data
    with open('assets/data/quran_uthmani.json', 'r', encoding='utf-8') as f:
        our_data = json.load(f)
    
    our_verses = {}
    for v in our_data['quran']:
        key = f"{v['chapter']}:{v['verse']}"
        our_verses[key] = v
    
    print(f"Current data has {len(our_verses)} verses")
    
    # Fetch all verses from API
    api_verses = {}
    total_diffs = 0
    
    for surah in range(1, 115):
        print(f"Fetching surah {surah}...", end=" ", flush=True)
        verses = fetch_surah(surah)
        count = 0
        for v in verses:
            key = v['verse_key']
            api_text = v['text_uthmani']
            api_verses[key] = api_text
            
            if key in our_verses:
                our_text = our_verses[key]['text']
                if api_text.strip() != our_text.strip():
                    count += 1
        print(f"{len(verses)} verses, {count} diffs")
        total_diffs += count
        time.sleep(0.3)  # Rate limit
    
    print(f"\nTotal differences: {total_diffs}")
    
    # Apply fixes - update text in our data
    fixed_count = 0
    for v in our_data['quran']:
        key = f"{v['chapter']}:{v['verse']}"
        if key in api_verses:
            api_text = api_verses[key]
            if api_text.strip() != v['text'].strip():
                v['text'] = api_text
                fixed_count += 1
    
    print(f"Fixed {fixed_count} verses")
    
    # Save updated data
    with open('assets/data/quran_uthmani.json', 'w', encoding='utf-8') as f:
        json.dump(our_data, f, ensure_ascii=False, separators=(',', ':'))
    
    print("Saved updated quran_uthmani.json")
    
    # Verify a few known problematic verses
    print("\nVerification:")
    test_keys = ['26:3', '26:5', '26:10', '26:12', '26:213', '26:222', '26:224', '26:227']
    for key in test_keys:
        if key in our_verses:
            new_text = next(v['text'] for v in our_data['quran'] if f"{v['chapter']}:{v['verse']}" == key)
            print(f"  {key}: {new_text[:60]}...")

if __name__ == '__main__':
    main()
