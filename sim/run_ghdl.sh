#!/bin/sh
#==============================================================================
# Simulacion del MPDII con GHDL (alternativa libre a ModelSim).
#   uso:  cd sim && sh run_ghdl.sh
# Genera mpdii.vcd, que se puede abrir con GTKWave.
#==============================================================================
set -e

mkdir -p build
cd build

SRC="../../rtl/mux2to1_8.vhd ../../rtl/mux4to1_8.vhd ../../rtl/inc8.vhd \
     ../../rtl/alu8.vhd ../../rtl/shifter8.vhd ../../rtl/tristate8.vhd \
     ../../rtl/flags.vhd ../../rtl/reg8.vhd ../../rtl/reg13.vhd \
     ../../rtl/regfile16x8.vhd ../../rtl/rom256x13.vhd \
     ../../rtl/datapath.vhd ../../rtl/control_unit.vhd ../../rtl/MPDII.vhd \
     ../tb_MPDII.vhd"

echo "== Analisis =="
for f in $SRC; do
    ghdl -a --std=93c "$f"
done

echo "== Elaboracion =="
ghdl -e --std=93c tb_MPDII

echo "== Ejecucion =="
ghdl -r --std=93c tb_MPDII --vcd=mpdii.vcd --stop-time=7us

echo
echo "Listo. Forma de onda en sim/build/mpdii.vcd  ->  gtkwave mpdii.vcd"
