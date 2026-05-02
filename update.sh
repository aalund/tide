#!/usr/bin/env bash
set -euo pipefail

TODAY_URL="https://www.tidepeek.com/europe/denmark/central-jutland/norddjurs-kommune/grena-havn"
TOMORROW_URL="https://www.tidepeek.com/europe/denmark/central-jutland/norddjurs-kommune/grena-havn/tomorrow"
TMP_TODAY="$(mktemp)"
TMP_TOMORROW="$(mktemp)"
trap 'rm -f "$TMP_TODAY" "$TMP_TOMORROW"' EXIT

curl -fsSL "$TODAY_URL" -o "$TMP_TODAY"
curl -fsSL "$TOMORROW_URL" -o "$TMP_TOMORROW"

python3 - <<'PY' "$TMP_TODAY" "$TMP_TOMORROW"
import json
import re
import sys
from datetime import datetime, timedelta, UTC
from pathlib import Path

src_today = Path(sys.argv[1]).read_text(encoding='utf-8', errors='ignore')
src_tomorrow = Path(sys.argv[2]).read_text(encoding='utf-8', errors='ignore')
out = Path('index.html')

weekday_map = ['mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'lørdag', 'søndag']
month_map = ['januar', 'februar', 'marts', 'april', 'maj', 'juni', 'juli', 'august', 'september', 'oktober', 'november', 'december']


def parse_page(src, target_date, day_label):
    rows = re.findall(r'<tr><td.*?</td><td>(\d{1,2}:\d{2}\s*[AP]M)</td><td>(-?\d+(?:\.\d+)?)</td></tr>', src, re.IGNORECASE)
    kinds = re.findall(r'<tr><td><img[^>]+/>(Low tide|High tide)</td><td>\d{1,2}:\d{2}\s*[AP]M</td><td>-?\d+(?:\.\d+)?</td></tr>', src, re.IGNORECASE)
    if not rows or not kinds or len(rows) != len(kinds):
        raise SystemExit(f'Could not parse tide table for {day_label}')

    entries = []
    for (time_str, level), kind in zip(rows, kinds):
        dk_kind = 'Højvande' if kind.lower() == 'high tide' else 'Lavvande'
        level_ft = float(level)
        level_m = level_ft * 0.3048
        if abs(level_m) < 0.05:
            level_str = '0,0'
        else:
            level_str = f'{level_m:.1f}'.replace('.', ',')
        dt = datetime.strptime(time_str.upper(), '%I:%M %p')
        entries.append({
            'time': dt.strftime('%H:%M'),
            'level': level_str,
            'kind': dk_kind,
            'emoji': '🌊' if dk_kind == 'Højvande' else '⬇️',
            'pillClass': 'high' if dk_kind == 'Højvande' else 'low'
        })

    entries.sort(key=lambda x: x['time'])
    date_str = f"{weekday_map[target_date.weekday()]} {target_date.day}. {month_map[target_date.month-1]} {target_date.year}"
    return {
        'label': day_label,
        'date': date_str,
        'entries': entries,
    }

now = datetime.now(UTC)
today = now.date()
tomorrow = today + timedelta(days=1)
updated_str = now.strftime('%d-%m-%Y %H:%M UTC')

data = {
    'today': parse_page(src_today, today, 'I dag'),
    'tomorrow': parse_page(src_tomorrow, tomorrow, 'I morgen'),
}

json_blob = json.dumps(data, ensure_ascii=False)

html = f'''<!DOCTYPE html>
<html lang="da">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>Tidevand – Grenaa</title>
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="theme-color" content="#07263d">
  <meta name="description" content="Tidevand for Grenaa Havn – i dag og i morgen.">
  <style>
    :root {{
      --bg1: #041c2c;
      --bg2: #0b3c5d;
      --bg3: #1a6c8f;
      --card: rgba(255,255,255,0.88);
      --card-border: rgba(255,255,255,0.32);
      --text: #0b2f47;
      --muted: #5d7383;
      --line: rgba(11,60,93,0.10);
      --shadow: 0 20px 60px rgba(0,0,0,0.28);
      --high-bg: #dff4ff;
      --high-fg: #0d5f8c;
      --low-bg: #eef2f6;
      --low-fg: #4d6473;
    }}
    * {{ box-sizing: border-box; }}
    html, body {{
      margin: 0;
      min-height: 100%;
      font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at top, rgba(255,255,255,0.14), transparent 35%),
        linear-gradient(160deg, var(--bg1) 0%, var(--bg2) 50%, var(--bg3) 100%);
    }}
    body {{
      display: flex;
      align-items: center;
      justify-content: center;
      padding: max(18px, env(safe-area-inset-top)) 16px max(18px, env(safe-area-inset-bottom));
    }}
    .phone-shell {{ width: 100%; max-width: 430px; }}
    .card {{
      position: relative;
      overflow: hidden;
      border-radius: 28px;
      background: var(--card);
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
      border: 1px solid var(--card-border);
      box-shadow: var(--shadow);
      padding: 22px 18px 18px;
    }}
    .card::before {{ content: ''; position: absolute; inset: 0; background: linear-gradient(180deg, rgba(255,255,255,0.32), transparent 22%); pointer-events: none; }}
    .topbar {{ display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; font-size: 0.82rem; color: var(--muted); gap: 12px; }}
    .dot {{ width: 8px; height: 8px; border-radius: 50%; background: #2ecc71; display: inline-block; margin-right: 6px; box-shadow: 0 0 0 4px rgba(46,204,113,0.14); }}
    h1 {{ margin: 0; text-align: center; font-size: 1.9rem; letter-spacing: -0.03em; }}
    .location {{ text-align: center; margin-top: 0.35rem; color: var(--muted); font-size: 0.98rem; }}
    .switch {{ display: flex; gap: 8px; margin: 18px 0 16px; }}
    .switch-btn {{ flex: 1; border: 0; border-radius: 14px; padding: 12px 14px; font: inherit; font-weight: 700; cursor: pointer; background: rgba(255,255,255,0.65); color: var(--text); border: 1px solid rgba(11,60,93,0.10); }}
    .switch-btn.active {{ background: linear-gradient(135deg, rgba(7,38,61,0.95), rgba(26,108,143,0.88)); color: white; box-shadow: 0 10px 25px rgba(11,60,93,0.18); }}
    .hero {{ margin: 0 0 16px; padding: 18px; border-radius: 22px; background: linear-gradient(135deg, rgba(7,38,61,0.95), rgba(26,108,143,0.88)); color: white; text-align: center; box-shadow: inset 0 1px 0 rgba(255,255,255,0.08); }}
    .hero-label {{ font-size: 0.88rem; opacity: 0.8; margin-bottom: 0.4rem; }}
    .hero-date {{ font-size: 1.18rem; font-weight: 700; text-transform: capitalize; line-height: 1.35; }}
    .hero-sub {{ margin-top: 0.5rem; font-size: 0.92rem; opacity: 0.85; }}
    .list {{ display: grid; gap: 10px; }}
    .tide-row {{ display: grid; grid-template-columns: 1.3fr 0.8fr 0.8fr; gap: 10px; align-items: center; padding: 14px 12px; background: rgba(255,255,255,0.72); border: 1px solid rgba(11,60,93,0.08); border-radius: 18px; animation: rise 420ms ease both; }}
    .pill {{ display: inline-flex; align-items: center; gap: 0.35rem; border-radius: 999px; padding: 0.38rem 0.68rem; font-size: 0.9rem; font-weight: 700; white-space: nowrap; }}
    .pill.high {{ background: var(--high-bg); color: var(--high-fg); }}
    .pill.low {{ background: var(--low-bg); color: var(--low-fg); }}
    .tide-time {{ text-align: center; font-size: 1.4rem; font-weight: 800; letter-spacing: -0.03em; }}
    .tide-level {{ text-align: right; color: var(--muted); font-size: 0.95rem; font-weight: 600; }}
    .footer {{ margin-top: 14px; padding-top: 12px; border-top: 1px solid var(--line); color: var(--muted); font-size: 0.78rem; line-height: 1.55; text-align: center; }}
    .actions {{ display: flex; gap: 10px; margin-top: 14px; }}
    .button {{ flex: 1; text-align: center; text-decoration: none; color: white; background: linear-gradient(135deg, #0b3c5d, #1a6c8f); padding: 12px 14px; border-radius: 14px; font-weight: 700; box-shadow: 0 10px 25px rgba(11,60,93,0.18); border: 0; cursor: pointer; font: inherit; }}
    .button.secondary {{ background: rgba(255,255,255,0.7); color: var(--text); border: 1px solid rgba(11,60,93,0.10); box-shadow: none; }}
    @keyframes rise {{ from {{ opacity: 0; transform: translateY(8px); }} to {{ opacity: 1; transform: translateY(0); }} }}
    @media (max-width: 420px) {{
      .tide-row {{ grid-template-columns: 1fr auto; grid-template-areas: 'kind time' 'level level'; }}
      .tide-kind-wrap {{ grid-area: kind; }}
      .tide-time {{ grid-area: time; }}
      .tide-level {{ grid-area: level; text-align: left; padding-left: 2px; }}
      .topbar {{ flex-direction: column; align-items: flex-start; }}
    }}
  </style>
</head>
<body>
  <div class="phone-shell">
    <div class="card">
      <div class="topbar">
        <div><span class="dot"></span>Opdateret</div>
        <div>{updated_str}</div>
      </div>
      <h1>Tidevand</h1>
      <div class="location">Grenaa Havn</div>

      <div class="switch">
        <button id="btn-today" class="switch-btn active" type="button">I dag</button>
        <button id="btn-tomorrow" class="switch-btn" type="button">I morgen</button>
      </div>

      <div class="hero">
        <div class="hero-label" id="hero-label"></div>
        <div class="hero-date" id="hero-date"></div>
        <div class="hero-sub">Alle registrerede høj- og lavvander · 24-timers format · meter</div>
      </div>

      <div class="list" id="tide-list"></div>

      <div class="actions">
        <a class="button secondary" href="https://www.tidepeek.com/europe/denmark/central-jutland/norddjurs-kommune/grena-havn/tomorrow">Kilde</a>
        <button class="button" type="button" onclick="window.location.reload()">Opdater</button>
      </div>

      <div class="footer">
        Kilde: tidepeek.com<br>
        Vælg selv mellem i dag og i morgen.<br>
        Siden opdateres automatisk hver dag via GitHub Actions.
      </div>
    </div>
  </div>

  <script>
    const tideData = {json_blob};
    const list = document.getElementById('tide-list');
    const heroLabel = document.getElementById('hero-label');
    const heroDate = document.getElementById('hero-date');
    const btnToday = document.getElementById('btn-today');
    const btnTomorrow = document.getElementById('btn-tomorrow');

    function renderDay(key) {{
      const day = tideData[key];
      heroLabel.textContent = day.label;
      heroDate.textContent = day.date;
      list.innerHTML = day.entries.map((entry, idx) => `
        <div class="tide-row" style="animation-delay:${{idx * 40}}ms">
          <div class="tide-kind-wrap">
            <span class="pill ${{entry.pillClass}}">${{entry.emoji}} ${{entry.kind}}</span>
          </div>
          <div class="tide-time">${{entry.time}}</div>
          <div class="tide-level">${{entry.level}} m</div>
        </div>
      `).join('');

      btnToday.classList.toggle('active', key === 'today');
      btnTomorrow.classList.toggle('active', key === 'tomorrow');
    }}

    btnToday.addEventListener('click', () => renderDay('today'));
    btnTomorrow.addEventListener('click', () => renderDay('tomorrow'));

    renderDay('today');
  </script>
</body>
</html>
'''

out.write_text(html, encoding='utf-8')
print('Updated index.html')
PY
