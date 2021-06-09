Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
------------------------------------------------------------------------------------
| Tool Version : Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
| Date         : Sat May 15 10:26:50 2021
| Host         : rpeaseryzen running 64-bit Ubuntu 20.04.2 LTS
| Command      : report_timing -file synthesis/module/timing.t
| Design       : AXIStreamCompressor
| Device       : 7z020-clg400
| Speed File   : -1  PRODUCTION 1.12 2019-11-22
------------------------------------------------------------------------------------

Timing Report

Slack (MET) :             0.948ns  (required time - arrival time)
  Source:                 genblk1[1].StreamElement_inst/dataInCaptureBlock[4].USEStreamByteFifo_reg[4][2]/C
                            (rising edge-triggered cell FDRE clocked by sys_clk_100mhz  {rise@0.000ns fall@5.000ns period=10.000ns})
  Destination:            genblk1[1].StreamElement_inst/USEStreamByteLengthOut_reg[0]/CE
                            (rising edge-triggered cell FDRE clocked by sys_clk_100mhz  {rise@0.000ns fall@5.000ns period=10.000ns})
  Path Group:             sys_clk_100mhz
  Path Type:              Setup (Max at Slow Process Corner)
  Requirement:            10.000ns  (sys_clk_100mhz rise@10.000ns - sys_clk_100mhz rise@0.000ns)
  Data Path Delay:        8.670ns  (logic 2.469ns (28.478%)  route 6.201ns (71.522%))
  Logic Levels:           9  (CARRY4=2 LUT3=1 LUT4=1 LUT6=5)
  Clock Path Skew:        -0.145ns (DCD - SCD + CPR)
    Destination Clock Delay (DCD):    2.128ns = ( 12.128 - 10.000 ) 
    Source Clock Delay      (SCD):    2.456ns
    Clock Pessimism Removal (CPR):    0.184ns
  Clock Uncertainty:      0.035ns  ((TSJ^2 + TIJ^2)^1/2 + DJ) / 2 + PE
    Total System Jitter     (TSJ):    0.071ns
    Total Input Jitter      (TIJ):    0.000ns
    Discrete Jitter          (DJ):    0.000ns
    Phase Error              (PE):    0.000ns

    Location             Delay type                Incr(ns)  Path(ns)    Netlist Resource(s)
  -------------------------------------------------------------------    -------------------
                         (clock sys_clk_100mhz rise edge)
                                                      0.000     0.000 r  
                                                      0.000     0.000 r  clk (IN)
                         net (fo=0)                   0.000     0.000    clk
                         IBUF (Prop_ibuf_I_O)         0.972     0.972 r  clk_IBUF_inst/O
                         net (fo=1, unplaced)         0.800     1.771    clk_IBUF
                         BUFG (Prop_bufg_I_O)         0.101     1.872 r  clk_IBUF_BUFG_inst/O
                         net (fo=2369, unplaced)      0.584     2.456    genblk1[1].StreamElement_inst/clk_IBUF_BUFG
                         FDRE                                         r  genblk1[1].StreamElement_inst/dataInCaptureBlock[4].USEStreamByteFifo_reg[4][2]/C
  -------------------------------------------------------------------    -------------------
                         FDRE (Prop_fdre_C_Q)         0.478     2.934 r  genblk1[1].StreamElement_inst/dataInCaptureBlock[4].USEStreamByteFifo_reg[4][2]/Q
                         net (fo=5, unplaced)         0.993     3.927    genblk1[1].StreamElement_inst/dataInCaptureBlock[4].USEStreamByteFifo_reg[4][2]
                         LUT6 (Prop_lut6_I0_O)        0.295     4.222 f  genblk1[1].StreamElement_inst/USEStreamByteLength[5]_i_29__0/O
                         net (fo=1, unplaced)         0.449     4.671    genblk1[1].StreamElement_inst/USEStreamByteLength[5]_i_29__0_n_0
                         LUT4 (Prop_lut4_I3_O)        0.124     4.795 r  genblk1[1].StreamElement_inst/USEStreamByteLength[5]_i_15/O
                         net (fo=3, unplaced)         1.129     5.924    genblk1[1].StreamElement_inst/USEStreamByteLength[5]_i_15_n_0
                         LUT6 (Prop_lut6_I1_O)        0.124     6.048 r  genblk1[1].StreamElement_inst/USEStreamByteLength[0]_i_3/O
                         net (fo=1, unplaced)         0.902     6.950    genblk1[1].StreamElement_inst/USEStreamByteLength[0]_i_3_n_0
                         LUT6 (Prop_lut6_I0_O)        0.124     7.074 f  genblk1[1].StreamElement_inst/USEStreamByteLength[0]_i_2/O
                         net (fo=10, unplaced)        0.945     8.019    genblk1[1].StreamElement_inst/USEStreamByteLength[0]_i_2_n_0
                         LUT3 (Prop_lut3_I0_O)        0.148     8.167 f  genblk1[1].StreamElement_inst/USEStreamState0_carry_i_9/O
                         net (fo=2, unplaced)         0.460     8.627    genblk1[1].StreamElement_inst/USEStreamState0_carry_i_9_n_0
                         LUT6 (Prop_lut6_I5_O)        0.124     8.751 r  genblk1[1].StreamElement_inst/USEStreamState0_carry_i_2__2/O
                         net (fo=1, unplaced)         0.474     9.225    genblk1[1].StreamElement_inst/USEStreamState0_carry_i_2__2_n_0
                         CARRY4 (Prop_carry4_DI[2]_CO[3])
                                                      0.404     9.629 r  genblk1[1].StreamElement_inst/USEStreamState0_carry/CO[3]
                         net (fo=1, unplaced)         0.009     9.638    genblk1[1].StreamElement_inst/USEStreamState0_carry_n_0
                         CARRY4 (Prop_carry4_CI_CO[0])
                                                      0.281     9.919 r  genblk1[1].StreamElement_inst/USEStreamState0_carry__0/CO[0]
                         net (fo=4, unplaced)         0.335    10.254    genblk1[1].StreamElement_inst/USEStreamState0_carry__0_n_3
                         LUT6 (Prop_lut6_I0_O)        0.367    10.621 r  genblk1[1].StreamElement_inst/USEStreamByteLengthOut[5]_i_2/O
                         net (fo=6, unplaced)         0.505    11.126    genblk1[1].StreamElement_inst/USEStreamByteLengthOut[5]_i_2_n_0
                         FDRE                                         r  genblk1[1].StreamElement_inst/USEStreamByteLengthOut_reg[0]/CE
  -------------------------------------------------------------------    -------------------

                         (clock sys_clk_100mhz rise edge)
                                                     10.000    10.000 r  
                                                      0.000    10.000 r  clk (IN)
                         net (fo=0)                   0.000    10.000    clk
                         IBUF (Prop_ibuf_I_O)         0.838    10.838 r  clk_IBUF_inst/O
                         net (fo=1, unplaced)         0.760    11.598    clk_IBUF
                         BUFG (Prop_bufg_I_O)         0.091    11.689 r  clk_IBUF_BUFG_inst/O
                         net (fo=2369, unplaced)      0.439    12.128    genblk1[1].StreamElement_inst/clk_IBUF_BUFG
                         FDRE                                         r  genblk1[1].StreamElement_inst/USEStreamByteLengthOut_reg[0]/C
                         clock pessimism              0.184    12.311    
                         clock uncertainty           -0.035    12.276    
                         FDRE (Setup_fdre_C_CE)      -0.202    12.074    genblk1[1].StreamElement_inst/USEStreamByteLengthOut_reg[0]
  -------------------------------------------------------------------
                         required time                         12.074    
                         arrival time                         -11.126    
  -------------------------------------------------------------------
                         slack                                  0.948    




