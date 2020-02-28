#!/bin/sh

iverilog -W all -o uart uart.v uart_tb.v || exit 1

IVERILOG_DUMPER=lxt2 vvp uart

gtkwave uart_tb.lxt
