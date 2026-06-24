# Makefile for UART project

SIM_DIR = sim
RTL_DIR = rtl
TB_DIR = tb

# iverilog executable
IVC = iverilog
VVP = vvp

all: test_uart_tx test_baud_gen test_uart_rx test_uart_loopback test_spi_master test_spi_slave test_spi_loopback test_spi_modes test_i2c_start_stop test_i2c_ack_nack test_i2c_single_byte test_i2c_address test_i2c_multi_byte test_i2c_clock_stretch

test_baud_gen: $(SIM_DIR)/baud_gen.vvp
	$(VVP) $(SIM_DIR)/baud_gen.vvp

$(SIM_DIR)/baud_gen.vvp: $(RTL_DIR)/uart/baud_gen.v $(TB_DIR)/uart/baud_gen_tb.v
	$(IVC) -o $@ $^

test_uart_rx: $(SIM_DIR)/uart_rx.vvp
	$(VVP) $(SIM_DIR)/uart_rx.vvp

$(SIM_DIR)/uart_rx.vvp: $(RTL_DIR)/uart/uart_rx.v $(TB_DIR)/uart/uart_rx_tb.v
	$(IVC) -o $@ $^

test_uart_tx: $(SIM_DIR)/uart_tx.vvp
	$(VVP) $(SIM_DIR)/uart_tx.vvp

$(SIM_DIR)/uart_tx.vvp: $(RTL_DIR)/uart/uart_tx.v $(TB_DIR)/uart/uart_tx_tb.v
	$(IVC) -o $@ $^

test_uart_loopback: $(SIM_DIR)/uart_loopback.vvp
	$(VVP) $(SIM_DIR)/uart_loopback.vvp

$(SIM_DIR)/uart_loopback.vvp: $(RTL_DIR)/uart/uart_tx.v $(RTL_DIR)/uart/uart_rx.v $(RTL_DIR)/uart/uart_top.v $(TB_DIR)/uart/uart_loopback_tb.v
	$(IVC) -o $@ $^

test_spi_master: $(SIM_DIR)/spi_master.vvp
	$(VVP) $(SIM_DIR)/spi_master.vvp

$(SIM_DIR)/spi_master.vvp: $(RTL_DIR)/spi/spi_master.v $(TB_DIR)/spi/spi_master_tb.v
	$(IVC) -o $@ $^

test_spi_slave: $(SIM_DIR)/spi_slave.vvp
	$(VVP) $(SIM_DIR)/spi_slave.vvp

$(SIM_DIR)/spi_slave.vvp: $(RTL_DIR)/spi/spi_slave.v $(TB_DIR)/spi/spi_slave_tb.v
	$(IVC) -o $@ $^

test_spi_loopback: $(SIM_DIR)/spi_loopback.vvp
	$(VVP) $(SIM_DIR)/spi_loopback.vvp

$(SIM_DIR)/spi_loopback.vvp: $(RTL_DIR)/spi/spi_master.v $(RTL_DIR)/spi/spi_slave.v $(TB_DIR)/spi/spi_loopback_tb.v
	$(IVC) -o $@ $^

test_spi_modes: $(SIM_DIR)/spi_modes.vvp
	$(VVP) $(SIM_DIR)/spi_modes.vvp

$(SIM_DIR)/spi_modes.vvp: $(RTL_DIR)/spi/spi_master.v $(RTL_DIR)/spi/spi_slave.v $(TB_DIR)/spi/spi_modes_tb.v
	$(IVC) -o $@ $^

test_i2c_start_stop: $(SIM_DIR)/i2c_start_stop.vvp
	$(VVP) $(SIM_DIR)/i2c_start_stop.vvp

$(SIM_DIR)/i2c_start_stop.vvp: $(RTL_DIR)/i2c/i2c_master.v $(TB_DIR)/i2c/i2c_start_stop_tb.v
	$(IVC) -o $@ $^

test_i2c_ack_nack: $(SIM_DIR)/i2c_ack_nack.vvp
	$(VVP) $(SIM_DIR)/i2c_ack_nack.vvp

$(SIM_DIR)/i2c_ack_nack.vvp: $(RTL_DIR)/i2c/i2c_master.v $(TB_DIR)/i2c/i2c_ack_nack_tb.v
	$(IVC) -o $@ $^

test_i2c_single_byte: $(SIM_DIR)/i2c_single_byte.vvp
	$(VVP) $(SIM_DIR)/i2c_single_byte.vvp

$(SIM_DIR)/i2c_single_byte.vvp: $(RTL_DIR)/i2c/i2c_master.v $(TB_DIR)/i2c/i2c_single_byte_tb.v
	$(IVC) -o $@ $^

test_i2c_address: $(SIM_DIR)/i2c_address.vvp
	$(VVP) $(SIM_DIR)/i2c_address.vvp

$(SIM_DIR)/i2c_address.vvp: $(RTL_DIR)/i2c/i2c_master.v $(TB_DIR)/i2c/i2c_address_tb.v
	$(IVC) -o $@ $^

test_i2c_multi_byte: $(SIM_DIR)/i2c_multi_byte.vvp
	$(VVP) $(SIM_DIR)/i2c_multi_byte.vvp

$(SIM_DIR)/i2c_multi_byte.vvp: $(RTL_DIR)/i2c/i2c_master.v $(TB_DIR)/i2c/i2c_multi_byte_tb.v
	$(IVC) -o $@ $^

test_i2c_clock_stretch: $(SIM_DIR)/i2c_clock_stretch.vvp
	$(VVP) $(SIM_DIR)/i2c_clock_stretch.vvp

$(SIM_DIR)/i2c_clock_stretch.vvp: $(RTL_DIR)/i2c/i2c_master.v $(TB_DIR)/i2c/i2c_clock_stretch_tb.v
	$(IVC) -o $@ $^

clean:
	rm -f $(SIM_DIR)/*.vvp $(SIM_DIR)/*.vcd

.PHONY: all test_uart_tx clean
