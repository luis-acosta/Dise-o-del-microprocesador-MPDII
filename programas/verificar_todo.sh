#!/bin/sh
#==============================================================================
# Compila y simula con GHDL los nueve programas del MPDII, uno por uno.
#
# Cada programa trae su propia version de rom256x13.vhd, y todas declaran la
# misma entidad, asi que cada corrida necesita un directorio de trabajo limpio.
# Por eso el script crea uno temporal para cada una y lo borra al terminar.
#
#   uso:  cd programas && sh verificar_todo.sh
#==============================================================================
set -u

BASE=$(cd "$(dirname "$0")/.." && pwd)
RTL=$BASE/rtl
SIM=$BASE/sim
PRG=$BASE/programas

COMUNES="mux2to1_8 mux4to1_8 inc8 alu8 shifter8 tristate8 flags reg8 reg13 \
regfile16x8 datapath control_unit MPDII"

fallos=0

correr() {
    rom=$1; tb=$2; nombre=$3
    d=$(mktemp -d)
    cd "$d" || return

    for f in $COMUNES; do
        ghdl -a --std=93c "$RTL/$f.vhd" >/dev/null 2>&1 || {
            echo "  FALLO  $nombre   (no compila $f.vhd)"
            fallos=$((fallos + 1)); cd /tmp; rm -rf "$d"; return; }
    done

    ghdl -a --std=93c "$rom" >/dev/null 2>&1 || {
        echo "  FALLO  $nombre   (no compila la ROM)"
        fallos=$((fallos + 1)); cd /tmp; rm -rf "$d"; return; }

    ghdl -a --std=93c "$tb" >/dev/null 2>&1 || {
        echo "  FALLO  $nombre   (no compila el banco de pruebas)"
        fallos=$((fallos + 1)); cd /tmp; rm -rf "$d"; return; }

    unidad=$(basename "$tb" .vhd)
    ghdl -e --std=93c "$unidad" >/dev/null 2>&1 || {
        echo "  FALLO  $nombre   (no elabora)"
        fallos=$((fallos + 1)); cd /tmp; rm -rf "$d"; return; }

    if ghdl -r --std=93c "$unidad" --stop-time=300us 2>&1 | grep -q "PRUEBA SUPERADA"; then
        echo "  OK     $nombre"
    else
        echo "  FALLO  $nombre   (la simulacion no supero las comprobaciones)"
        fallos=$((fallos + 1))
    fi

    cd /tmp; rm -rf "$d"
}

echo "Verificacion de los nueve programas del MPDII"
echo
echo "PRUEBAS DEL MICROPROCESADOR"
correr "$PRG/rom256x13_saltos.vhd"      "$PRG/tb_saltos.vhd"      "saltos          JMP JZ JNZ JP JN"
correr "$PRG/rom256x13_alu.vhd"         "$PRG/tb_alu.vhd"         "ALU             las 8 operaciones"
correr "$PRG/rom256x13_es.vhd"          "$PRG/tb_es.vhd"          "entrada/salida  IN y OUT"
echo
echo "APLICACIONES"
correr "$RTL/rom256x13.vhd"             "$SIM/tb_MPDII.vhd"       "division        15 / 3 = 5"
correr "$PRG/rom256x13_suma.vhd"        "$PRG/tb_suma.vhd"        "suma            25 + 17 = 42"
correr "$PRG/rom256x13_rotacion.vhd"    "$PRG/tb_rotacion.vhd"    "rotacion        un 1 por 8 posiciones"
correr "$PRG/rom256x13_mayor.vhd"       "$PRG/tb_mayor.vhd"       "mayor           comparacion"
correr "$PRG/rom256x13_multiplica.vhd"  "$PRG/tb_multiplica.vhd"  "multiplicacion  sumas sucesivas"
correr "$PRG/rom256x13_mult_shift.vhd"  "$PRG/tb_mult_shift.vhd"  "mult 16 bits    desplazar y sumar"

echo
if [ "$fallos" -eq 0 ]; then
    echo "Los nueve programas pasaron."
else
    echo "$fallos programa(s) fallaron."
    exit 1
fi
