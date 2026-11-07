# fpga-multitimezone-clock
A digital clock that shows multiple timezomes, date, days of the week. Has the ability to set an alarm, start a timer and stopwatch, also displays the temperature. Implemented using a Nexys 4 DDR (verilog, vivado)


## Features

- **Six cities** from one clock. Pick one with the switches.
- **Date and weekday** that stay correct across midnight, month ends and leap years
- **Stopwatch** with 0.01 s resolution
- **Countdown timer** that beeps at zero
- **Alarm** on India time that beeps and flashes the LEDs
- **Room temperature** from the on-board ADT7420 sensor over I²C
- All 16 LEDs show a seconds bar on the TIME screen (Every 3.75 seconds more LEDs light up as the minute progresses)
- Temperature based mood lighting; LD16 fades from blue (16 °C or colder) through green (24 °C) to red (32 °C or hotter) with the room temperature.
- City based colour codes, LD17 shows colour for the selected city- India Orange, Tokyo white, Paris blue, London purple, Beijing  Red, New York green.  
- Stopwatch, timer and alarm keep running when you switch screens
- ***DOES NOT INCLUDE DAY LIGHT SAVINGS TIME FOR NYC, PARIS AND LONDON.***

### City selection

| SW2 SW1 SW0 | City (letter on display) | Offset from UTC |
|---|---|---|
| 000 | India (H) | +5:30 |
| 001 | Tokyo (t) | +9 |
| 010 | Paris (P) | +2 |
| 011 | London (L) | +1 |
| 100 | Beijing (b) | +8 |
| 101 | New York (n) | −4 |

- ***DOES NOT INCLUDE DAY LIGHT SAVINGS TIME FOR NYC, PARIS AND LONDON.***

## Hardware and tools

- Board: Digilent Nexys 4 DDR (100 MHz clock)
- Language: Verilog-2001
- Tool: Xilinx Vivado 2020.1
- Timing: all constraints met

## Controls

**BTNC** moves to the next screen: TIME → DATE → STOPWATCH → TIMER → ALARM → TEMP → TIME.
**CPU RESET** resets the clock.

| Screen | BTNU | BTND | BTNL | BTNR |
|---|---|---|---|---|
| Time | Hour + 1 | Minute + 1 | – | – |
| Date | Day + 1 | Month + 1 | Year + 1 | Date / weekday |
| Stopwatch | – | – | Start / stop | Reset |
| Timer | Minute + 1 | Second + 1 | Start / pause | Reset |
| Alarm | Hour + 1 | Minute + 1 | On / off | – |
| Temperature | – | – | – | – |

Any button press or shake silences a ringing timer or alarm.

### Shake and tilt

| Action | Result |
|---|---|
| **Shake** the board (always on) | Silences a ringing timer or alarm |
| **Tilt right** (SW14 up) | Next screen |
| **Tilt left** (SW14 up) | Previous screen |


- A shake is 4 quick jerks within about half a second, so a single knock on the table is ignored.
- A tilt must be held for a short moment, which stops accidental screen changes.
- Flip **SW14 down** to turn tilt control off.

| File | Purpose |
|---|---|
| `clock_top.v` | Top level, connects everything |
| `clk_divider.v` | Makes the 1 kHz, 100 Hz and 1 Hz enable ticks from 100 MHz |
| `reset_sync.v` | Reset synchroniser |
| `debounce.v` | Button and switch debouncing |
| `mode_fsm.v` | Screen-selection state machine |
| `time_counter.v` | Hours, minutes, seconds |
| `timezone_offset.v` | City offsets |
| `date_counter.v`, `weekday.v` | Date, leap year and day of the week |
| `stopwatch.v`, `countdown_timer.v`, `alarm_clock.v` | Stopwatch, timer, alarm |
| `beeper.v` | 2 kHz tone for the audio jack |
| `temp_sensor_adt7420.v`, `i2c_master.v`, `temp_to_bcd.v` | Temperature reading |
| `adxl362_spi.v` | SPI driver that reads the accelerometer |
| `motion_detect.v` | Detects shake and tilt from the accelerometer readings |
| `bin2bcd.v` | Binary to BCD conversion |
| `display_mux.v`, `seg7_driver.v` | Seven-segment display |
| `seconds_bar.v`, `rgb_mood.v` | LED effects |
| `constraints/nexys4ddr.xdc` | Pin constraints |
| `sim/tb_clock_top.v` | Simulation testbench |

## How to build

1. Open Vivado and create a new RTL project for part **XC7A100TCSG324-1**.
2. Add all the `.v` files as design sources and `nexys4ddr.xdc` as the constraints file.
3. Set `clock_top` as the top module.
4. Run Synthesis, Implementation, then Generate Bitstream.
5. Connect the board and program it from Hardware Manager.

## How to simulate

1. Add `sim/tb_clock_top.v` as a simulation source and set `tb_clock_top` as the simulation top.
2. Run Behavioural Simulation, then type `log_wave -r /`, `restart` and `run all` in the Tcl console.
3. Add `display_text` to the waveform and set its radix to ASCII to read the display.

The testbench speeds the clock up (one clock second lasts 20 ms) so the whole run finishes in about 135 ms of simulation time.
