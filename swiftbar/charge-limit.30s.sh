#!/bin/bash
# <xbar.title>macOS Charge Limiter</xbar.title>
# <xbar.desc>Menu bar control for the charge limiter daemon</xbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
BIN=/usr/local/bin
DIR="$HOME/.charge-limit"
FLAG="$DIR/on"
MAX=$(cat "$DIR/max" 2>/dev/null || echo 80)
MIN=$((MAX - 5))

# Language: ~/.charge-limit/lang (en|ru) overrides the primary system language
LANG_CODE=$(cat "$DIR/lang" 2>/dev/null || defaults read -g AppleLanguages 2>/dev/null | sed -n 2p)
if [[ "$LANG_CODE" == *ru* ]]; then
  T_ON="Лимит ${MAX}%: включён"; T_OFF="Лимит: выключен"
  T_DISCH="Разряжаю до ${MAX}% (адаптер не используется)"
  T_ALLOWED="Зарядка разрешена"; T_HELD="Зарядка остановлена (держу ${MIN}–${MAX}%)"
  T_POWER="Питание"; T_DISABLE="Выключить лимит (зарядить до 100%)"
  T_ENABLE="Включить лимит ${MAX}%"; T_LEVEL="Порог зарядки"; T_DTOGGLE="Разряжать до порога"
else
  T_ON="Limit ${MAX}%: on"; T_OFF="Limit: off"
  T_DISCH="Discharging to ${MAX}% (adapter bypassed)"
  T_ALLOWED="Charging allowed"; T_HELD="Charging paused (holding ${MIN}–${MAX}%)"
  T_POWER="Power"; T_DISABLE="Disable limit (charge to 100%)"
  T_ENABLE="Enable ${MAX}% limit"; T_LEVEL="Charge limit"; T_DTOGGLE="Discharge to limit"
fi

batt=$(pmset -g batt)
chte=$($BIN/smc -k CHTE -r | grep -Eo 'bytes [0-9a-f ]+')
chie=$($BIN/smc -k CHIE -r | grep -Eo 'bytes [0-9a-f ]+')

if [[ "$chie" != "bytes 00" ]]; then
  echo " | sfimage=arrow.down.circle.fill"
elif [[ -f "$FLAG" ]]; then
  echo " | sfimage=leaf.fill"
else
  echo " | sfimage=bolt.fill"
fi
echo "---"
if [[ -f "$FLAG" ]]; then
  echo "$T_ON | sfimage=checkmark.circle.fill"
else
  echo "$T_OFF | sfimage=circle"
fi
if [[ "$chie" != "bytes 00" ]]; then
  echo "$T_DISCH"
elif [[ "$chte" == "bytes 00 00 00 00" ]]; then
  echo "$T_ALLOWED"
else
  echo "$T_HELD"
fi
grep -Eo "'[^']+'" <<<"$batt" | head -1 | tr -d "'" | sed "s/^/$T_POWER: /"
echo "---"
if [[ -f "$FLAG" ]]; then
  echo "$T_DISABLE | bash=$BIN/charge-limit-off terminal=false refresh=true"
else
  echo "$T_ENABLE | bash=$BIN/charge-limit-on terminal=false refresh=true"
fi
echo "$T_LEVEL"
for n in 50 60 70 75 80 85 90 95; do
  if [[ "$n" == "$MAX" ]]; then
    echo "--${n}% | checked=true bash=$BIN/charge-limit-on param1=$n terminal=false refresh=true"
  else
    echo "--${n}% | bash=$BIN/charge-limit-on param1=$n terminal=false refresh=true"
  fi
done
if [[ -f "$DIR/discharge" ]]; then
  echo "$T_DTOGGLE | checked=true bash=$BIN/charge-limit-discharge param1=off terminal=false refresh=true"
else
  echo "$T_DTOGGLE | bash=$BIN/charge-limit-discharge param1=on terminal=false refresh=true"
fi
