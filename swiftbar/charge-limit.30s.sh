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

# System language: the first supported entry in the
# preference list wins, English is the fallback. ~/.charge-limit/lang overrides it.
SYS_LANG=en
for l in $(defaults read -g AppleLanguages 2>/dev/null | tr -d '(),"'); do
  case "$l" in en*|ru*|uk*) SYS_LANG=${l:0:2}; break ;; esac
done

set_strings() {
  case "$(cat "$DIR/lang" 2>/dev/null || echo "$SYS_LANG")" in
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
}

# One ioreg call and one awk pass per update. Top-level keys look like
# `  "Voltage" = 12500`, keys inside nested dictionaries like `"SystemVoltageIn"=19813`.
# Prints shell assignments with already formatted values (mV, mA, mW in).
read_power() {
  ioreg -rn AppleSmartBattery | awk '
    function sub_val(k,   m) { if (match($0, "\"" k "\"=[0-9-]+")) return substr($0, RSTART + length(k) + 3, RLENGTH - length(k) - 3); return "" }
    /^ *"ExternalConnected" = / { plugged = $3 }
    /^ *"Voltage" = /           { bv = $3 }
    /^ *"Amperage" = /          { ba = $3
                                  # negative currents come as unsigned 64-bit (2^64 - n); doubles cannot
                                  # subtract that precisely, so use the last 6 digits of 18446744073709551616
                                  if (length(ba) == 20 && substr(ba, 1, 14) == "18446744073709") ba = substr(ba, 15) - 551616 }
    /^ *"Temperature" = /       { temp = $3 }
    /"AdapterDetails" = /       { watts = sub_val("Watts"); avolt = sub_val("AdapterVoltage") }
    /"PowerTelemetryData" = /   { vin = sub_val("SystemVoltageIn"); iin = sub_val("SystemCurrentIn"); pin = sub_val("SystemPowerIn") }
    END {
      sign = ba > 0 ? "+" : ""
      printf "plugged=%s\n", plugged
      if (watts != "") printf "adapter=\"%d W (%.0f V)\"\n", watts, avolt / 1000
      if (vin != "")   printf "input=\"%.2f V · %.2f A · %.1f W\"\n", vin / 1000, iin / 1000, pin / 1000
      if (bv != "")    printf "battery=\"%.2f V · %s%.2f A · %s%.1f W\"\n", bv / 1000, sign, ba / 1000, sign, bv * ba / 1e6
      if (temp != "")  printf "temp=\"%.1f °C\"\n", temp / 100
    }'
}

render() {
  MAX=$(cat "$DIR/max" 2>/dev/null || echo 80)
  MIN=$((MAX - 5))
  set_strings
  plugged= adapter= input= battery= temp=
  eval "$(read_power)"
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
  # CHIE bypasses the adapter, so it counts as running from battery
  if [[ "$plugged" == "Yes" && "$chie" == "bytes 00" ]]; then
    echo "$T_POWER: $T_AC"
  else
    echo "$T_POWER: $T_BATT"
  fi

  # Electrical readings (mV, mA, mW)
  echo "---"
  if [[ "$plugged" == "Yes" ]]; then
    [[ -n "$adapter" ]] && echo "$T_ADAPTER: $adapter | sfimage=powerplug"
    [[ -n "$input" ]] && echo "$T_INPUT: $input | sfimage=bolt"
  fi
  [[ -n "$battery" ]] && echo "$T_BATTERY: $battery | sfimage=battery.75percent"
  [[ -n "$temp" ]] && echo "$T_TEMP: $temp | sfimage=thermometer.medium"

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
}

render
