#!/bin/bash
# <xbar.title>macOS Charge Limiter</xbar.title>
# <xbar.desc>Menu bar control for the charge limiter daemon</xbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>
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
    T_ADAPTER="Адаптер"; T_INPUT="Вход"; T_BATTERY="Батарея"; T_TEMP="Температура"
    T_LEVEL="Порог зарядки"; T_DTOGGLE="Разряжать до порога" ;;
  uk*)
    T_ON="Ліміт ${MAX}%: увімкнено"; T_OFF="Ліміт: вимкнено"
    T_DISCH="Розряджаю до ${MAX}% (адаптер не використовується)"
    T_ALLOWED="Заряджання дозволено"; T_HELD="Заряджання призупинено (тримаю ${MIN}–${MAX}%)"
    T_POWER="Живлення"; T_AC="мережа"; T_BATT="батарея"
    T_DISABLE="Вимкнути ліміт (зарядити до 100%)"; T_ENABLE="Увімкнути ліміт ${MAX}%"
    T_ADAPTER="Адаптер"; T_INPUT="Вхід"; T_BATTERY="Батарея"; T_TEMP="Температура"
    T_LEVEL="Поріг заряджання"; T_DTOGGLE="Розряджати до порога" ;;
  *)
    T_ON="Limit ${MAX}%: on"; T_OFF="Limit: off"
    T_DISCH="Discharging to ${MAX}% (adapter bypassed)"
    T_ALLOWED="Charging allowed"; T_HELD="Charging paused (holding ${MIN}–${MAX}%)"
    T_POWER="Power"; T_AC="AC adapter"; T_BATT="battery"
    T_DISABLE="Disable limit (charge to 100%)"; T_ENABLE="Enable ${MAX}% limit"
    T_ADAPTER="Adapter"; T_INPUT="Input"; T_BATTERY="Battery"; T_TEMP="Temperature"
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

# Electrical readings from the battery controller (mV, mA, mW)
io=$(ioreg -rn AppleSmartBattery -a)
io_val() { plutil -extract "0.$1" raw -o - - <<<"$io" 2>/dev/null; }
fmt() { awk -v x="$1" -v d="$2" -v u="$3" 'BEGIN { printf "%." d "f %s", x / 1000, u }'; }
echo "---"
if [[ "$(io_val ExternalConnected)" == "true" ]]; then
  watts=$(io_val AdapterDetails.Watts); avolt=$(io_val AdapterDetails.AdapterVoltage)
  [[ -n "$watts" ]] && echo "$T_ADAPTER: $watts W ($(fmt "$avolt" 0 V)) | sfimage=powerplug"
  vin=$(io_val PowerTelemetryData.SystemVoltageIn); iin=$(io_val PowerTelemetryData.SystemCurrentIn)
  pin=$(io_val PowerTelemetryData.SystemPowerIn)
  [[ -n "$vin" ]] && echo "$T_INPUT: $(fmt "$vin" 2 V) · $(fmt "$iin" 2 A) · $(fmt "$pin" 1 W) | sfimage=bolt"
fi
bv=$(io_val Voltage); ba=$(io_val Amperage)
if [[ -n "$bv" && -n "$ba" ]]; then
  ba=$(( ba ))  # wraps unsigned 64-bit values to negative
  bw=$(( bv * ba / 1000 ))
  sign=""; (( ba > 0 )) && sign="+"
  echo "$T_BATTERY: $(fmt "$bv" 2 V) · $sign$(fmt "$ba" 2 A) · $sign$(fmt "$bw" 1 W) | sfimage=battery.75percent"
fi
temp=$(io_val Temperature)
[[ -n "$temp" ]] && echo "$T_TEMP: $(awk -v t="$temp" 'BEGIN { printf "%.1f", t / 100 }') °C | sfimage=thermometer.medium"
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
