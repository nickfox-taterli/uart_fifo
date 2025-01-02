set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rxd]
set_property IOSTANDARD LVCMOS33 [get_ports txd]
set_property PACKAGE_PIN G22 [get_ports clk]
set_property PACKAGE_PIN G26 [get_ports rst_n]
set_property PACKAGE_PIN H12 [get_ports rxd]
set_property PACKAGE_PIN H14 [get_ports txd]

create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]