set_property PACKAGE_PIN B4 [get_ports {gtDataTxP}]
set_property PACKAGE_PIN A4 [get_ports {gtDataTxN}]
set_property PACKAGE_PIN B8 [get_ports {gtDataRxP}]
set_property PACKAGE_PIN A8 [get_ports {gtDataRxN}]

set_property PACKAGE_PIN F6 [get_ports {gtRefClk0P}]
#set_property PACKAGE_PIN E6 [get_ports {gtRefClk0N}]

set_property PACKAGE_PIN R16 [get_ports {sfpDisable}]
set_property IOSTANDARD LVCMOS33 [get_ports {sfpDisable}]

set_property PACKAGE_PIN Y6  [get_ports {led[0]}]
set_property PACKAGE_PIN AA6 [get_ports {led[1]}]
set_property PACKAGE_PIN L5  [get_ports {led[2]}]
set_property PACKAGE_PIN L4  [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {led[*]}]

create_clock -period 8.000 -name gtRefClk0P -waveform {0.000 4.000} [get_ports gtRefClk0P]

# Configuration properties
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
#set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
#set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]
#set_property BITSTREAM.STARTUP.STARTUPCLK Cclk [current_design]
