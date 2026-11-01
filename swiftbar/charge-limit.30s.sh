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

# Language: ~/.charge-limit/lang (en|ru|uk) overrides the system language.
# Otherwise the first supported language in the system preference list wins, English is the fallback.
LANG_CODE=$(cat "$DIR/lang" 2>/dev/null)
if [[ -z "$LANG_CODE" ]]; then
  for l in $(defaults read -g AppleLanguages 2>/dev/null | tr -d '(),"'); do
    case "$l" in en*|ru*|uk*) LANG_CODE=${l:0:2}; break ;; esac
  done
fi

case "$LANG_CODE" in
  ru*)
    T_ON="Лимит ${MAX}%: включён"; T_OFF="Лимит: выключен"
    T_DISCH="Разряжаю до ${MAX}% (адаптер не используется)"
    T_ALLOWED="Зарядка разрешена"; T_HELD="Зарядка остановлена (держу ${MIN}–${MAX}%)"
    T_POWER="Питание"; T_AC="сеть"; T_BATT="батарея"
    T_DISABLE="Выключить лимит (зарядить до 100%)"; T_ENABLE="Включить лимит ${MAX}%"
    T_LEVEL="Порог зарядки"; T_DTOGGLE="Разряжать до порога" ;;
  uk*)
    T_ON="Ліміт ${MAX}%: увімкнено"; T_OFF="Ліміт: вимкнено"
    T_DISCH="Розряджаю до ${MAX}% (адаптер не використовується)"
    T_ALLOWED="Заряджання дозволено"; T_HELD="Заряджання призупинено (тримаю ${MIN}–${MAX}%)"
    T_POWER="Живлення"; T_AC="мережа"; T_BATT="батарея"
    T_DISABLE="Вимкнути ліміт (зарядити до 100%)"; T_ENABLE="Увімкнути ліміт ${MAX}%"
    T_LEVEL="Поріг заряджання"; T_DTOGGLE="Розряджати до порога" ;;
  *)
    T_ON="Limit ${MAX}%: on"; T_OFF="Limit: off"
    T_DISCH="Discharging to ${MAX}% (adapter bypassed)"
    T_ALLOWED="Charging allowed"; T_HELD="Charging paused (holding ${MIN}–${MAX}%)"
    T_POWER="Power"; T_AC="AC adapter"; T_BATT="battery"
    T_DISABLE="Disable limit (charge to 100%)"; T_ENABLE="Enable ${MAX}% limit"
    T_LEVEL="Charge limit"; T_DTOGGLE="Discharge to limit" ;;
esac

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
if grep -q "'AC Power'" <<<"$batt"; then echo "$T_POWER: $T_AC"; else echo "$T_POWER: $T_BATT"; fi
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
