// This is the unpowered netlist.
module lcd_ili9341_top (clk,
    frame_start,
    init_done,
    pix_next,
    rst_n,
    tft_cs,
    tft_dc,
    tft_mosi,
    tft_sck,
    pix_gray);
 input clk;
 output frame_start;
 output init_done;
 output pix_next;
 input rst_n;
 output tft_cs;
 output tft_dc;
 output tft_mosi;
 output tft_sck;
 input [7:0] pix_gray;

 wire _000_;
 wire _001_;
 wire _002_;
 wire _003_;
 wire _004_;
 wire _005_;
 wire _006_;
 wire _007_;
 wire _008_;
 wire _009_;
 wire _010_;
 wire _011_;
 wire _012_;
 wire _013_;
 wire _014_;
 wire _015_;
 wire _016_;
 wire _017_;
 wire _018_;
 wire _019_;
 wire _020_;
 wire _021_;
 wire _022_;
 wire _023_;
 wire _024_;
 wire _025_;
 wire _026_;
 wire _027_;
 wire _028_;
 wire _029_;
 wire _030_;
 wire _031_;
 wire _032_;
 wire _033_;
 wire _034_;
 wire _035_;
 wire _036_;
 wire _037_;
 wire _038_;
 wire _039_;
 wire _040_;
 wire _041_;
 wire _042_;
 wire _043_;
 wire _044_;
 wire _045_;
 wire _046_;
 wire _047_;
 wire _048_;
 wire _049_;
 wire _050_;
 wire _051_;
 wire _052_;
 wire _053_;
 wire _054_;
 wire _055_;
 wire _056_;
 wire _057_;
 wire _058_;
 wire _059_;
 wire _060_;
 wire _061_;
 wire _062_;
 wire _063_;
 wire _064_;
 wire _065_;
 wire _066_;
 wire _067_;
 wire _068_;
 wire _069_;
 wire _070_;
 wire _071_;
 wire _072_;
 wire _073_;
 wire _074_;
 wire _075_;
 wire _076_;
 wire _077_;
 wire _078_;
 wire _079_;
 wire _080_;
 wire _081_;
 wire _082_;
 wire _083_;
 wire _084_;
 wire _085_;
 wire _086_;
 wire _087_;
 wire _088_;
 wire _089_;
 wire _090_;
 wire _091_;
 wire _092_;
 wire _093_;
 wire _094_;
 wire _095_;
 wire _096_;
 wire _097_;
 wire _098_;
 wire _099_;
 wire _100_;
 wire _101_;
 wire _102_;
 wire _103_;
 wire _104_;
 wire _105_;
 wire _106_;
 wire _107_;
 wire _108_;
 wire _109_;
 wire _110_;
 wire _111_;
 wire _112_;
 wire _113_;
 wire _114_;
 wire _115_;
 wire _116_;
 wire _117_;
 wire _118_;
 wire _119_;
 wire _120_;
 wire _121_;
 wire _122_;
 wire _123_;
 wire _124_;
 wire _125_;
 wire _126_;
 wire _127_;
 wire _128_;
 wire _129_;
 wire _130_;
 wire _131_;
 wire _132_;
 wire _133_;
 wire _134_;
 wire _135_;
 wire _136_;
 wire _137_;
 wire _138_;
 wire _139_;
 wire _140_;
 wire _141_;
 wire _142_;
 wire _143_;
 wire _144_;
 wire _145_;
 wire _146_;
 wire _147_;
 wire _148_;
 wire _149_;
 wire _150_;
 wire _151_;
 wire _152_;
 wire _153_;
 wire _154_;
 wire _155_;
 wire _156_;
 wire _157_;
 wire _158_;
 wire _159_;
 wire _160_;
 wire _161_;
 wire _162_;
 wire _163_;
 wire _164_;
 wire _165_;
 wire _166_;
 wire _167_;
 wire _168_;
 wire _169_;
 wire _170_;
 wire _171_;
 wire _172_;
 wire _173_;
 wire _174_;
 wire _175_;
 wire _176_;
 wire _177_;
 wire _178_;
 wire _179_;
 wire _180_;
 wire _181_;
 wire _182_;
 wire _183_;
 wire _184_;
 wire _185_;
 wire _186_;
 wire _187_;
 wire _188_;
 wire _189_;
 wire _190_;
 wire _191_;
 wire _192_;
 wire _193_;
 wire _194_;
 wire _195_;
 wire _196_;
 wire _197_;
 wire _198_;
 wire _199_;
 wire _200_;
 wire _201_;
 wire _202_;
 wire _203_;
 wire _204_;
 wire _205_;
 wire _206_;
 wire _207_;
 wire _208_;
 wire _209_;
 wire _210_;
 wire _211_;
 wire _212_;
 wire _213_;
 wire _214_;
 wire _215_;
 wire _216_;
 wire _217_;
 wire _218_;
 wire _219_;
 wire _220_;
 wire _221_;
 wire _222_;
 wire _223_;
 wire _224_;
 wire _225_;
 wire _226_;
 wire _227_;
 wire _228_;
 wire _229_;
 wire _230_;
 wire _231_;
 wire _232_;
 wire _233_;
 wire _234_;
 wire _235_;
 wire _236_;
 wire _237_;
 wire _238_;
 wire _239_;
 wire _240_;
 wire _241_;
 wire _242_;
 wire _243_;
 wire _244_;
 wire _245_;
 wire _246_;
 wire _247_;
 wire _248_;
 wire _249_;
 wire _250_;
 wire _251_;
 wire _252_;
 wire _253_;
 wire _254_;
 wire _255_;
 wire _256_;
 wire _257_;
 wire _258_;
 wire _259_;
 wire _260_;
 wire _261_;
 wire _262_;
 wire _263_;
 wire _264_;
 wire _265_;
 wire _266_;
 wire _267_;
 wire _268_;
 wire _269_;
 wire _270_;
 wire _271_;
 wire _272_;
 wire _273_;
 wire _274_;
 wire _275_;
 wire _276_;
 wire _277_;
 wire _278_;
 wire _279_;
 wire _280_;
 wire _281_;
 wire _282_;
 wire _283_;
 wire _284_;
 wire _285_;
 wire _286_;
 wire _287_;
 wire _288_;
 wire _289_;
 wire _290_;
 wire _291_;
 wire _292_;
 wire _293_;
 wire _294_;
 wire _295_;
 wire _296_;
 wire _297_;
 wire _298_;
 wire _299_;
 wire _300_;
 wire _301_;
 wire _302_;
 wire _303_;
 wire _304_;
 wire _305_;
 wire _306_;
 wire _307_;
 wire _308_;
 wire _309_;
 wire _310_;
 wire _311_;
 wire _312_;
 wire _313_;
 wire _314_;
 wire _315_;
 wire _316_;
 wire _317_;
 wire _318_;
 wire _319_;
 wire _320_;
 wire _321_;
 wire _322_;
 wire _323_;
 wire _324_;
 wire _325_;
 wire _326_;
 wire _327_;
 wire _328_;
 wire _329_;
 wire _330_;
 wire _331_;
 wire _332_;
 wire _333_;
 wire _334_;
 wire _335_;
 wire _336_;
 wire _337_;
 wire _338_;
 wire _339_;
 wire _340_;
 wire _341_;
 wire _342_;
 wire _343_;
 wire _344_;
 wire _345_;
 wire _346_;
 wire _347_;
 wire _348_;
 wire _349_;
 wire _350_;
 wire _351_;
 wire _352_;
 wire _353_;
 wire _354_;
 wire _355_;
 wire _356_;
 wire _357_;
 wire _358_;
 wire _359_;
 wire _360_;
 wire _361_;
 wire _362_;
 wire _363_;
 wire _364_;
 wire _365_;
 wire _366_;
 wire _367_;
 wire _368_;
 wire _369_;
 wire _370_;
 wire _371_;
 wire _372_;
 wire clknet_0_clk;
 wire clknet_3_0__leaf_clk;
 wire clknet_3_1__leaf_clk;
 wire clknet_3_2__leaf_clk;
 wire clknet_3_3__leaf_clk;
 wire clknet_3_4__leaf_clk;
 wire clknet_3_5__leaf_clk;
 wire clknet_3_6__leaf_clk;
 wire clknet_3_7__leaf_clk;
 wire \dcnt[0] ;
 wire \dcnt[10] ;
 wire \dcnt[11] ;
 wire \dcnt[12] ;
 wire \dcnt[13] ;
 wire \dcnt[14] ;
 wire \dcnt[15] ;
 wire \dcnt[16] ;
 wire \dcnt[17] ;
 wire \dcnt[18] ;
 wire \dcnt[19] ;
 wire \dcnt[1] ;
 wire \dcnt[20] ;
 wire \dcnt[2] ;
 wire \dcnt[3] ;
 wire \dcnt[4] ;
 wire \dcnt[5] ;
 wire \dcnt[6] ;
 wire \dcnt[7] ;
 wire \dcnt[8] ;
 wire \dcnt[9] ;
 wire \dmode[0] ;
 wire \dmode[1] ;
 wire \dmode[2] ;
 wire \dmode[3] ;
 wire \ip[0] ;
 wire \ip[1] ;
 wire \ip[2] ;
 wire \ip[3] ;
 wire \ip[4] ;
 wire net1;
 wire net10;
 wire net11;
 wire net12;
 wire net13;
 wire net14;
 wire net15;
 wire net16;
 wire net17;
 wire net18;
 wire net19;
 wire net2;
 wire net20;
 wire net21;
 wire net22;
 wire net23;
 wire net24;
 wire net25;
 wire net26;
 wire net27;
 wire net28;
 wire net29;
 wire net3;
 wire net30;
 wire net31;
 wire net32;
 wire net33;
 wire net34;
 wire net35;
 wire net36;
 wire net37;
 wire net38;
 wire net39;
 wire net4;
 wire net40;
 wire net41;
 wire net42;
 wire net43;
 wire net44;
 wire net45;
 wire net46;
 wire net47;
 wire net48;
 wire net49;
 wire net5;
 wire net50;
 wire net51;
 wire net52;
 wire net53;
 wire net54;
 wire net55;
 wire net56;
 wire net57;
 wire net58;
 wire net59;
 wire net6;
 wire net60;
 wire net61;
 wire net62;
 wire net63;
 wire net64;
 wire net65;
 wire net66;
 wire net67;
 wire net68;
 wire net69;
 wire net7;
 wire net70;
 wire net71;
 wire net72;
 wire net73;
 wire net74;
 wire net75;
 wire net76;
 wire net77;
 wire net78;
 wire net79;
 wire net8;
 wire net80;
 wire net81;
 wire net82;
 wire net83;
 wire net9;
 wire \pcolor_l[0] ;
 wire \pcolor_l[1] ;
 wire \pcolor_l[2] ;
 wire \pcolor_l[3] ;
 wire \pcolor_l[4] ;
 wire \pcolor_l[5] ;
 wire \px[0] ;
 wire \px[10] ;
 wire \px[11] ;
 wire \px[12] ;
 wire \px[13] ;
 wire \px[14] ;
 wire \px[15] ;
 wire \px[16] ;
 wire \px[1] ;
 wire \px[2] ;
 wire \px[3] ;
 wire \px[4] ;
 wire \px[5] ;
 wire \px[6] ;
 wire \px[7] ;
 wire \px[8] ;
 wire \px[9] ;
 wire pxhi;
 wire \sbit[0] ;
 wire \sbit[1] ;
 wire \sbit[2] ;
 wire \sbuf[0] ;
 wire \sbuf[1] ;
 wire \sbuf[2] ;
 wire \sbuf[3] ;
 wire \sbuf[4] ;
 wire \sbuf[5] ;
 wire \sbuf[6] ;
 wire \sbuf[7] ;
 wire sending;
 wire \spi_byte[0] ;
 wire \spi_byte[1] ;
 wire \spi_byte[2] ;
 wire \spi_byte[3] ;
 wire \spi_byte[4] ;
 wire \spi_byte[5] ;
 wire \spi_byte[6] ;
 wire \spi_byte[7] ;
 wire spi_dcbit;
 wire spi_done;
 wire spi_start;
 wire \sst[0] ;
 wire \sst[1] ;
 wire \sst[2] ;
 wire \sst[3] ;

 sky130_fd_sc_hd__decap_3 FILLER_0_0_109 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_0_113 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_0_121 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_128 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_153 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_0_165 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_169 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_0_18 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_0_181 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_0_188 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_209 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_0_221 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_225 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_0_237 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_0_241 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_0_26 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_29 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_0_41 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_0_49 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_0_55 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_57 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_6 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_69 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_0_81 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_85 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_0_97 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_10_11 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_10_127 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_10_133 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_10_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_10_16 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_10_187 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_10_195 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_10_197 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_10_209 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_10_217 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_10_229 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_10_241 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_10_247 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_10_29 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_10_3 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_10_41 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_10_45 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_10_71 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_10_83 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_10_85 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_10_98 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_11_111 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_11_113 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_11_122 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_11_134 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_11_146 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_11_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_11_156 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_11_177 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_11_189 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_11_19 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_11_210 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_11_222 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_11_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_11_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_11_33 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_11_45 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_11_53 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_11_63 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_11_75 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_11_83 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_12_110 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_12_133 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_12_139 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_12_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_12_148 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_12_160 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_12_173 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_12_194 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_12_217 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_12_237 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_12_246 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_12_29 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_12_3 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_12_48 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_12_56 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_12_7 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_12_75 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_12_83 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_13_106 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_13_113 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_13_129 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_13_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_13_155 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_13_167 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_13_181 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_13_193 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_13_209 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_13_213 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_13_222 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_13_26 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_13_3 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_13_46 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_13_52 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_13_57 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_13_78 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_13_94 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_14_123 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_14_137 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_14_15 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_14_154 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_14_164 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_14_173 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_14_185 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_14_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_14_197 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_14_209 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_14_224 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_14_236 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_14_27 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_14_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_14_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_14_45 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_14_57 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_14_64 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_14_69 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_14_81 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_14_85 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_14_97 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_15_101 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_15_110 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_15_15 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_15_153 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_15_162 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_15_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_15_202 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_15_214 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_15_218 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_15_234 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_15_246 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_15_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_15_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_15_32 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_15_44 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_15_52 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_15_57 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_15_65 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_15_71 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_15_79 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_15_91 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_16_112 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_16_119 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_16_127 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_16_131 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_16_135 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_16_139 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_16_151 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_16_158 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_16_178 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_16_190 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_16_205 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_16_211 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_16_240 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_16_53 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_16_65 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_16_71 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_16_83 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_17_110 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_17_113 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_17_125 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_17_137 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_17_153 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_17_164 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_17_169 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_17_175 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_17_196 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_17_221 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_17_225 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_17_237 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_17_243 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_17_3 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_17_32 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_17_51 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_17_63 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_17_71 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_17_75 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_17_87 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_17_93 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_17_98 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_18_100 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_18_112 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_18_124 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_18_132 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_18_139 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_18_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_18_15 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_18_153 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_18_157 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_18_164 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_18_172 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_18_231 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_18_243 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_18_247 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_18_27 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_18_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_18_3 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_18_42 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_18_51 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_18_72 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_18_80 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_18_85 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_18_89 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_19_120 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_19_134 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_19_140 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_19_148 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_19_162 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_19_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_19_181 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_19_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_19_208 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_19_220 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_19_225 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_19_235 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_19_247 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_19_29 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_19_33 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_19_40 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_19_53 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_19_70 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_19_82 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_19_86 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_1_105 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_1_111 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_113 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_125 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_137 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_149 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_15 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_1_161 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_1_167 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_181 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_205 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_1_217 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_1_223 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_225 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_1_237 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_1_245 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_39 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_1_51 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_1_55 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_57 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_69 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_81 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_1_93 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_20_111 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_20_139 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_20_150 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_20_173 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_20_185 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_20_193 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_20_197 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_20_205 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_20_21 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_20_227 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_20_27 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_20_40 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_20_51 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_20_63 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_20_75 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_20_85 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_20_9 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_21_111 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_21_113 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_21_15 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_21_158 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_21_166 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_21_181 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_21_202 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_21_246 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_21_3 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_21_52 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_21_57 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_21_89 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_22_111 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_22_123 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_22_133 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_22_139 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_22_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_22_148 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_22_15 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_22_160 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_22_186 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_22_194 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_22_197 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_22_205 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_22_214 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_22_225 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_22_237 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_22_27 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_22_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_22_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_22_50 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_22_62 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_22_69 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_22_82 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_22_91 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_22_95 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_22_99 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_23_107 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_23_111 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_113 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_125 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_137 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_23_149 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_15 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_23_154 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_23_166 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_23_175 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_209 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_23_221 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_225 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_23_243 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_23_247 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_39 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_23_51 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_23_55 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_23_78 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_23_90 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_23_94 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_24_106 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_24_113 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_24_117 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_24_128 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_24_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_24_15 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_24_158 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_24_171 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_24_183 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_24_195 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_24_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_24_221 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_24_233 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_24_241 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_24_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_24_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_24_3 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_24_41 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_24_47 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_24_78 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_24_85 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_24_92 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_25_107 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_25_111 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_25_134 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_25_146 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_25_15 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_25_157 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_25_165 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_25_169 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_25_181 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_25_208 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_25_218 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_25_225 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_25_235 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_25_247 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_25_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_25_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_25_39 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_25_51 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_25_55 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_25_60 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_25_72 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_26_111 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_26_127 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_26_139 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_26_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_26_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_26_169 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_26_181 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_26_192 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_26_210 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_26_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_26_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_26_3 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_26_41 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_26_80 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_26_85 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_27_123 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_27_142 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_27_149 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_27_15 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_27_161 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_27_167 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_27_217 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_27_236 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_27_244 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_27_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_27_3 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_27_39 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_27_43 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_27_51 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_27_55 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_27_57 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_27_71 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_27_82 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_27_94 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_28_104 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_28_116 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_28_120 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_28_129 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_28_137 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_28_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_28_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_28_178 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_28_190 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_28_246 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_28_27 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_28_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_28_3 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_28_35 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_28_44 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_28_55 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_28_81 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_28_92 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_29_105 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_29_111 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_29_113 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_29_15 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_29_164 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_29_169 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_29_175 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_29_213 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_29_23 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_29_237 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_29_245 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_29_3 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_29_54 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_29_60 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_29_72 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_29_93 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_124 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_2_136 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_153 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_165 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_177 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_2_189 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_2_195 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_209 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_2_221 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_2_227 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_2_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_41 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_53 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_65 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_2_77 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_2_83 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_2_85 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_2_97 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_30_106 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_30_118 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_30_130 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_30_138 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_30_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_30_15 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_30_172 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_30_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_30_197 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_30_209 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_30_231 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_30_243 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_30_247 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_30_27 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_30_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_30_3 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_30_37 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_30_65 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_30_77 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_30_83 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_31_103 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_31_111 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_31_113 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_31_121 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_31_127 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_31_139 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_31_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_31_151 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_31_163 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_31_167 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_31_169 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_31_177 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_31_183 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_31_195 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_31_207 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_31_219 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_31_223 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_31_225 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_31_237 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_31_245 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_31_36 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_31_40 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_31_48 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_31_57 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_31_63 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_31_71 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_31_83 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_31_9 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_31_93 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_32_112 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_32_136 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_144 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_32_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_156 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_168 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_180 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_32_192 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_209 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_221 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_32_23 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_233 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_32_245 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_32_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_32_3 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_32_85 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_32_91 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_33_128 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_33_139 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_33_15 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_33_161 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_33_167 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_33_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_33_181 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_33_19 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_33_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_33_205 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_33_217 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_33_223 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_33_225 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_33_237 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_33_245 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_33_3 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_33_57 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_33_61 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_33_74 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_33_86 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_33_90 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_34_115 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_34_122 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_34_139 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_34_146 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_170 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_182 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_34_194 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_209 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_221 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_233 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_34_245 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_34_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_3 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_34_41 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_34_51 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_62 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_34_74 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_34_82 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_34_85 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_34_97 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_35_106 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_35_118 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_35_129 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_156 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_181 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_205 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_35_217 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_35_223 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_225 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_35_237 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_35_245 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_3 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_35_39 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_35_48 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_35_53 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_57 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_69 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_35_81 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_35_93 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_106 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_36_118 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_36_126 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_36_130 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_36_134 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_155 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_167 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_179 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_36_191 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_36_195 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_209 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_221 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_233 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_36_245 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_36_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_36_3 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_36_66 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_36_85 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_36_91 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_37_110 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_37_113 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_37_117 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_37_128 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_37_136 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_37_15 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_37_158 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_37_166 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_37_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_37_181 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_37_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_37_205 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_37_217 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_37_223 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_37_225 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_37_237 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_37_245 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_37_3 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_37_43 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_37_55 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_37_62 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_37_99 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_38_123 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_38_137 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_146 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_158 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_170 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_182 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_38_194 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_209 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_221 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_233 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_38_245 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_38_27 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_38_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_38_3 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_38_37 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_38_63 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_38_71 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_38_80 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_38_85 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_38_95 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_39_102 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_39_106 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_39_113 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_155 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_39_167 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_181 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_205 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_39_217 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_39_223 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_225 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_39_237 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_39_245 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_3 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_39_39 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_39_55 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_39_85 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_39_90 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_3_101 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_3_109 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_3_116 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_3_120 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_129 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_3_141 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_3_147 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_3_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_181 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_205 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_3_217 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_3_223 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_228 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_3_240 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_77 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_3_89 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_40_113 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_40_124 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_15 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_161 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_173 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_40_185 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_40_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_209 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_221 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_233 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_40_245 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_40_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_40_3 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_40_41 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_40_62 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_41_109 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_113 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_41_125 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_41_137 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_141 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_153 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_41_165 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_181 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_41_193 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_209 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_41_21 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_41_221 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_41_225 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_41_233 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_41_27 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_41_29 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_37 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_41_49 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_41_55 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_57 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_69 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_41_81 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_85 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_9 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_41_97 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_4_109 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_4_120 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_4_126 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_4_130 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_4_149 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_15 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_4_153 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_4_157 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_4_161 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_4_169 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_179 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_4_191 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_4_195 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_197 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_209 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_221 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_233 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_4_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_32 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_44 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_4_56 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_65 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_4_77 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_4_83 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_85 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_4_97 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_5_107 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_5_111 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_5_113 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_5_121 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_5_142 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_5_15 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_5_164 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_5_178 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_5_203 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_5_233 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_5_247 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_5_27 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_5_3 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_5_32 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_5_40 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_5_47 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_5_53 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_5_70 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_5_93 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_5_97 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_6_122 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_6_134 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_6_141 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_6_153 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_6_175 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_6_242 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_6_27 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_6_57 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_6_6 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_6_80 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_6_85 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_6_93 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_7_100 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_7_113 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_7_119 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_7_123 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_7_133 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_7_142 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_7_162 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_7_169 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_7_210 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_7_243 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_7_247 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_7_29 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_7_47 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_7_57 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_7_61 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_8_105 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_8_113 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_8_135 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_8_139 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_8_150 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_8_197 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_8_207 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_8_212 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_8_222 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_8_25 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_8_3 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_8_39 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_8_51 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_8_59 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_8_66 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_8_77 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_8_83 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_8_93 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_9_101 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_9_122 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_9_13 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_9_130 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_9_178 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_9_182 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_9_206 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_9_218 ();
 sky130_ef_sc_hd__decap_12 FILLER_0_9_234 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_9_246 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_9_3 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_9_45 ();
 sky130_fd_sc_hd__decap_4 FILLER_0_9_51 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_9_55 ();
 sky130_fd_sc_hd__decap_6 FILLER_0_9_66 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_9_72 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_9_9 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_9_93 ();
 sky130_fd_sc_hd__decap_3 PHY_0 ();
 sky130_fd_sc_hd__decap_3 PHY_1 ();
 sky130_fd_sc_hd__decap_3 PHY_10 ();
 sky130_fd_sc_hd__decap_3 PHY_11 ();
 sky130_fd_sc_hd__decap_3 PHY_12 ();
 sky130_fd_sc_hd__decap_3 PHY_13 ();
 sky130_fd_sc_hd__decap_3 PHY_14 ();
 sky130_fd_sc_hd__decap_3 PHY_15 ();
 sky130_fd_sc_hd__decap_3 PHY_16 ();
 sky130_fd_sc_hd__decap_3 PHY_17 ();
 sky130_fd_sc_hd__decap_3 PHY_18 ();
 sky130_fd_sc_hd__decap_3 PHY_19 ();
 sky130_fd_sc_hd__decap_3 PHY_2 ();
 sky130_fd_sc_hd__decap_3 PHY_20 ();
 sky130_fd_sc_hd__decap_3 PHY_21 ();
 sky130_fd_sc_hd__decap_3 PHY_22 ();
 sky130_fd_sc_hd__decap_3 PHY_23 ();
 sky130_fd_sc_hd__decap_3 PHY_24 ();
 sky130_fd_sc_hd__decap_3 PHY_25 ();
 sky130_fd_sc_hd__decap_3 PHY_26 ();
 sky130_fd_sc_hd__decap_3 PHY_27 ();
 sky130_fd_sc_hd__decap_3 PHY_28 ();
 sky130_fd_sc_hd__decap_3 PHY_29 ();
 sky130_fd_sc_hd__decap_3 PHY_3 ();
 sky130_fd_sc_hd__decap_3 PHY_30 ();
 sky130_fd_sc_hd__decap_3 PHY_31 ();
 sky130_fd_sc_hd__decap_3 PHY_32 ();
 sky130_fd_sc_hd__decap_3 PHY_33 ();
 sky130_fd_sc_hd__decap_3 PHY_34 ();
 sky130_fd_sc_hd__decap_3 PHY_35 ();
 sky130_fd_sc_hd__decap_3 PHY_36 ();
 sky130_fd_sc_hd__decap_3 PHY_37 ();
 sky130_fd_sc_hd__decap_3 PHY_38 ();
 sky130_fd_sc_hd__decap_3 PHY_39 ();
 sky130_fd_sc_hd__decap_3 PHY_4 ();
 sky130_fd_sc_hd__decap_3 PHY_40 ();
 sky130_fd_sc_hd__decap_3 PHY_41 ();
 sky130_fd_sc_hd__decap_3 PHY_42 ();
 sky130_fd_sc_hd__decap_3 PHY_43 ();
 sky130_fd_sc_hd__decap_3 PHY_44 ();
 sky130_fd_sc_hd__decap_3 PHY_45 ();
 sky130_fd_sc_hd__decap_3 PHY_46 ();
 sky130_fd_sc_hd__decap_3 PHY_47 ();
 sky130_fd_sc_hd__decap_3 PHY_48 ();
 sky130_fd_sc_hd__decap_3 PHY_49 ();
 sky130_fd_sc_hd__decap_3 PHY_5 ();
 sky130_fd_sc_hd__decap_3 PHY_50 ();
 sky130_fd_sc_hd__decap_3 PHY_51 ();
 sky130_fd_sc_hd__decap_3 PHY_52 ();
 sky130_fd_sc_hd__decap_3 PHY_53 ();
 sky130_fd_sc_hd__decap_3 PHY_54 ();
 sky130_fd_sc_hd__decap_3 PHY_55 ();
 sky130_fd_sc_hd__decap_3 PHY_56 ();
 sky130_fd_sc_hd__decap_3 PHY_57 ();
 sky130_fd_sc_hd__decap_3 PHY_58 ();
 sky130_fd_sc_hd__decap_3 PHY_59 ();
 sky130_fd_sc_hd__decap_3 PHY_6 ();
 sky130_fd_sc_hd__decap_3 PHY_60 ();
 sky130_fd_sc_hd__decap_3 PHY_61 ();
 sky130_fd_sc_hd__decap_3 PHY_62 ();
 sky130_fd_sc_hd__decap_3 PHY_63 ();
 sky130_fd_sc_hd__decap_3 PHY_64 ();
 sky130_fd_sc_hd__decap_3 PHY_65 ();
 sky130_fd_sc_hd__decap_3 PHY_66 ();
 sky130_fd_sc_hd__decap_3 PHY_67 ();
 sky130_fd_sc_hd__decap_3 PHY_68 ();
 sky130_fd_sc_hd__decap_3 PHY_69 ();
 sky130_fd_sc_hd__decap_3 PHY_7 ();
 sky130_fd_sc_hd__decap_3 PHY_70 ();
 sky130_fd_sc_hd__decap_3 PHY_71 ();
 sky130_fd_sc_hd__decap_3 PHY_72 ();
 sky130_fd_sc_hd__decap_3 PHY_73 ();
 sky130_fd_sc_hd__decap_3 PHY_74 ();
 sky130_fd_sc_hd__decap_3 PHY_75 ();
 sky130_fd_sc_hd__decap_3 PHY_76 ();
 sky130_fd_sc_hd__decap_3 PHY_77 ();
 sky130_fd_sc_hd__decap_3 PHY_78 ();
 sky130_fd_sc_hd__decap_3 PHY_79 ();
 sky130_fd_sc_hd__decap_3 PHY_8 ();
 sky130_fd_sc_hd__decap_3 PHY_80 ();
 sky130_fd_sc_hd__decap_3 PHY_81 ();
 sky130_fd_sc_hd__decap_3 PHY_82 ();
 sky130_fd_sc_hd__decap_3 PHY_83 ();
 sky130_fd_sc_hd__decap_3 PHY_9 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_100 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_101 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_102 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_103 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_104 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_105 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_106 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_107 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_108 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_109 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_110 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_111 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_112 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_113 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_114 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_115 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_116 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_117 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_118 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_119 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_120 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_121 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_122 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_123 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_124 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_125 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_126 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_127 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_128 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_129 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_130 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_131 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_132 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_133 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_134 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_135 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_136 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_137 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_138 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_139 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_140 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_141 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_142 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_143 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_144 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_145 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_146 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_147 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_148 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_149 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_150 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_151 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_152 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_153 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_154 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_155 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_156 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_157 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_158 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_159 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_160 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_161 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_162 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_163 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_164 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_165 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_166 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_167 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_168 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_169 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_170 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_171 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_172 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_173 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_174 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_175 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_176 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_177 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_178 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_179 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_180 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_181 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_182 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_183 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_184 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_185 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_186 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_187 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_188 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_189 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_190 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_191 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_192 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_193 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_194 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_195 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_196 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_197 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_198 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_199 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_200 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_201 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_202 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_203 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_204 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_205 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_206 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_207 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_208 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_209 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_210 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_211 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_212 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_213 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_214 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_215 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_216 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_217 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_218 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_219 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_220 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_221 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_222 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_223 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_224 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_225 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_226 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_227 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_228 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_229 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_230 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_231 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_232 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_233 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_234 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_235 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_236 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_237 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_238 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_239 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_240 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_241 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_242 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_243 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_244 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_245 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_246 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_247 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_248 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_249 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_250 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_251 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_252 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_253 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_254 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_255 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_256 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_257 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_258 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_259 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_84 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_85 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_86 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_87 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_88 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_89 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_90 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_91 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_92 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_93 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_94 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_95 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_96 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_97 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_98 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_99 ();
 sky130_fd_sc_hd__or2_1 _373_ (.A(\dmode[3] ),
    .B(\dmode[1] ),
    .X(_084_));
 sky130_fd_sc_hd__buf_1 _374_ (.A(_084_),
    .X(net9));
 sky130_fd_sc_hd__clkbuf_4 _375_ (.A(\dmode[2] ),
    .X(_085_));
 sky130_fd_sc_hd__and2b_2 _376_ (.A_N(\ip[2] ),
    .B(\ip[0] ),
    .X(_086_));
 sky130_fd_sc_hd__and2_1 _377_ (.A(\ip[3] ),
    .B(\ip[1] ),
    .X(_087_));
 sky130_fd_sc_hd__o21ai_2 _378_ (.A1(_086_),
    .A2(_087_),
    .B1(\dmode[2] ),
    .Y(_088_));
 sky130_fd_sc_hd__buf_2 _379_ (.A(\ip[3] ),
    .X(_089_));
 sky130_fd_sc_hd__clkbuf_4 _380_ (.A(\ip[0] ),
    .X(_090_));
 sky130_fd_sc_hd__a21o_1 _381_ (.A1(\ip[1] ),
    .A2(_090_),
    .B1(\ip[2] ),
    .X(_091_));
 sky130_fd_sc_hd__a21oi_2 _382_ (.A1(_089_),
    .A2(_091_),
    .B1(\ip[4] ),
    .Y(_092_));
 sky130_fd_sc_hd__buf_4 _383_ (.A(sending),
    .X(_093_));
 sky130_fd_sc_hd__a21oi_2 _384_ (.A1(_088_),
    .A2(_092_),
    .B1(_093_),
    .Y(_094_));
 sky130_fd_sc_hd__clkbuf_4 _385_ (.A(\ip[1] ),
    .X(_095_));
 sky130_fd_sc_hd__o31a_1 _386_ (.A1(\ip[2] ),
    .A2(_095_),
    .A3(_090_),
    .B1(\ip[3] ),
    .X(_096_));
 sky130_fd_sc_hd__a21o_1 _387_ (.A1(\ip[2] ),
    .A2(_090_),
    .B1(\ip[4] ),
    .X(_097_));
 sky130_fd_sc_hd__o21a_1 _388_ (.A1(_096_),
    .A2(_097_),
    .B1(\dmode[2] ),
    .X(_098_));
 sky130_fd_sc_hd__nand2_1 _389_ (.A(_094_),
    .B(_098_),
    .Y(_099_));
 sky130_fd_sc_hd__and2_1 _390_ (.A(\dcnt[17] ),
    .B(\dcnt[16] ),
    .X(_100_));
 sky130_fd_sc_hd__and2_1 _391_ (.A(\dcnt[8] ),
    .B(\dcnt[9] ),
    .X(_101_));
 sky130_fd_sc_hd__nor2_1 _392_ (.A(\dcnt[1] ),
    .B(\dcnt[0] ),
    .Y(_102_));
 sky130_fd_sc_hd__or4bb_1 _393_ (.A(\dcnt[7] ),
    .B(\dcnt[11] ),
    .C_N(\dcnt[10] ),
    .D_N(\dcnt[6] ),
    .X(_103_));
 sky130_fd_sc_hd__or4_1 _394_ (.A(\dcnt[3] ),
    .B(\dcnt[2] ),
    .C(\dcnt[5] ),
    .D(\dcnt[4] ),
    .X(_104_));
 sky130_fd_sc_hd__and4bb_1 _395_ (.A_N(\dcnt[15] ),
    .B_N(\dcnt[18] ),
    .C(\dcnt[19] ),
    .D(\dcnt[20] ),
    .X(_105_));
 sky130_fd_sc_hd__and3_1 _396_ (.A(\dcnt[13] ),
    .B(\dcnt[12] ),
    .C(\dcnt[14] ),
    .X(_106_));
 sky130_fd_sc_hd__and4bb_1 _397_ (.A_N(_103_),
    .B_N(_104_),
    .C(_105_),
    .D(_106_),
    .X(_107_));
 sky130_fd_sc_hd__and4_1 _398_ (.A(_100_),
    .B(_101_),
    .C(_102_),
    .D(_107_),
    .X(_108_));
 sky130_fd_sc_hd__buf_2 _399_ (.A(_108_),
    .X(_109_));
 sky130_fd_sc_hd__a22o_1 _400_ (.A1(_085_),
    .A2(_099_),
    .B1(_109_),
    .B2(net37),
    .X(_005_));
 sky130_fd_sc_hd__buf_4 _401_ (.A(\dmode[1] ),
    .X(_110_));
 sky130_fd_sc_hd__and2_1 _402_ (.A(_110_),
    .B(_094_),
    .X(_111_));
 sky130_fd_sc_hd__clkbuf_1 _403_ (.A(_111_),
    .X(_000_));
 sky130_fd_sc_hd__and4_1 _404_ (.A(\px[1] ),
    .B(\px[0] ),
    .C(\px[3] ),
    .D(\px[2] ),
    .X(_112_));
 sky130_fd_sc_hd__and4_1 _405_ (.A(\px[5] ),
    .B(\px[4] ),
    .C(\px[7] ),
    .D(\px[6] ),
    .X(_113_));
 sky130_fd_sc_hd__nand2_1 _406_ (.A(_112_),
    .B(_113_),
    .Y(_114_));
 sky130_fd_sc_hd__inv_2 _407_ (.A(net53),
    .Y(_115_));
 sky130_fd_sc_hd__or3b_1 _408_ (.A(\px[15] ),
    .B(\px[14] ),
    .C_N(\px[16] ),
    .X(_116_));
 sky130_fd_sc_hd__nand2_1 _409_ (.A(\px[9] ),
    .B(\px[8] ),
    .Y(_117_));
 sky130_fd_sc_hd__or3b_1 _410_ (.A(\px[10] ),
    .B(\px[12] ),
    .C_N(\px[11] ),
    .X(_118_));
 sky130_fd_sc_hd__or4_1 _411_ (.A(_115_),
    .B(_116_),
    .C(_117_),
    .D(_118_),
    .X(_119_));
 sky130_fd_sc_hd__nand3_1 _412_ (.A(sending),
    .B(spi_done),
    .C(pxhi),
    .Y(_120_));
 sky130_fd_sc_hd__or3_1 _413_ (.A(_114_),
    .B(_119_),
    .C(_120_),
    .X(_121_));
 sky130_fd_sc_hd__clkbuf_4 _414_ (.A(\dmode[3] ),
    .X(_122_));
 sky130_fd_sc_hd__a22oi_4 _415_ (.A1(_110_),
    .A2(_094_),
    .B1(_121_),
    .B2(_122_),
    .Y(_123_));
 sky130_fd_sc_hd__inv_2 _416_ (.A(_123_),
    .Y(_006_));
 sky130_fd_sc_hd__nand2b_2 _417_ (.A_N(spi_start),
    .B(\sst[0] ),
    .Y(_124_));
 sky130_fd_sc_hd__or2b_1 _418_ (.A(net26),
    .B_N(_124_),
    .X(_125_));
 sky130_fd_sc_hd__clkbuf_1 _419_ (.A(_125_),
    .X(_007_));
 sky130_fd_sc_hd__clkbuf_4 _420_ (.A(\sst[1] ),
    .X(_126_));
 sky130_fd_sc_hd__inv_2 _421_ (.A(_126_),
    .Y(_127_));
 sky130_fd_sc_hd__and3_1 _422_ (.A(\sbit[2] ),
    .B(\sbit[1] ),
    .C(\sbit[0] ),
    .X(_128_));
 sky130_fd_sc_hd__nand2_2 _423_ (.A(\sst[0] ),
    .B(net61),
    .Y(_129_));
 sky130_fd_sc_hd__o21ai_1 _424_ (.A1(_127_),
    .A2(_128_),
    .B1(_129_),
    .Y(_008_));
 sky130_fd_sc_hd__a21o_2 _425_ (.A1(_088_),
    .A2(_092_),
    .B1(sending),
    .X(_130_));
 sky130_fd_sc_hd__nor2_1 _426_ (.A(_114_),
    .B(_119_),
    .Y(_131_));
 sky130_fd_sc_hd__inv_2 _427_ (.A(\dmode[3] ),
    .Y(_132_));
 sky130_fd_sc_hd__clkbuf_4 _428_ (.A(_132_),
    .X(_133_));
 sky130_fd_sc_hd__nor2_1 _429_ (.A(_133_),
    .B(_120_),
    .Y(_001_));
 sky130_fd_sc_hd__a22oi_1 _430_ (.A1(_110_),
    .A2(_130_),
    .B1(_131_),
    .B2(_001_),
    .Y(_134_));
 sky130_fd_sc_hd__nand2_1 _431_ (.A(_099_),
    .B(_134_),
    .Y(_004_));
 sky130_fd_sc_hd__and2_1 _432_ (.A(\sst[1] ),
    .B(_128_),
    .X(_135_));
 sky130_fd_sc_hd__clkbuf_1 _433_ (.A(_135_),
    .X(_003_));
 sky130_fd_sc_hd__inv_2 _434_ (.A(net37),
    .Y(_136_));
 sky130_fd_sc_hd__nor2_1 _435_ (.A(_136_),
    .B(_109_),
    .Y(_002_));
 sky130_fd_sc_hd__nand2_1 _436_ (.A(_088_),
    .B(_092_),
    .Y(_137_));
 sky130_fd_sc_hd__inv_2 _437_ (.A(sending),
    .Y(_138_));
 sky130_fd_sc_hd__or2_2 _438_ (.A(\dmode[1] ),
    .B(\dmode[2] ),
    .X(_139_));
 sky130_fd_sc_hd__nand2_1 _439_ (.A(_138_),
    .B(_139_),
    .Y(_140_));
 sky130_fd_sc_hd__a2bb2o_1 _440_ (.A1_N(_137_),
    .A2_N(_140_),
    .B1(_138_),
    .B2(_122_),
    .X(_372_));
 sky130_fd_sc_hd__o21ai_2 _441_ (.A1(\sst[0] ),
    .A2(\sst[1] ),
    .B1(_124_),
    .Y(_141_));
 sky130_fd_sc_hd__nor2_1 _442_ (.A(_126_),
    .B(_141_),
    .Y(_142_));
 sky130_fd_sc_hd__a22o_1 _443_ (.A1(\sbuf[0] ),
    .A2(_141_),
    .B1(_142_),
    .B2(net30),
    .X(_009_));
 sky130_fd_sc_hd__mux2_1 _444_ (.A0(\spi_byte[1] ),
    .A1(\sbuf[0] ),
    .S(_126_),
    .X(_143_));
 sky130_fd_sc_hd__o21a_4 _445_ (.A1(\sst[0] ),
    .A2(_126_),
    .B1(_124_),
    .X(_144_));
 sky130_fd_sc_hd__mux2_1 _446_ (.A0(net69),
    .A1(_143_),
    .S(_144_),
    .X(_145_));
 sky130_fd_sc_hd__clkbuf_1 _447_ (.A(_145_),
    .X(_010_));
 sky130_fd_sc_hd__mux2_1 _448_ (.A0(\spi_byte[2] ),
    .A1(\sbuf[1] ),
    .S(_126_),
    .X(_146_));
 sky130_fd_sc_hd__mux2_1 _449_ (.A0(net63),
    .A1(_146_),
    .S(_144_),
    .X(_147_));
 sky130_fd_sc_hd__clkbuf_1 _450_ (.A(_147_),
    .X(_011_));
 sky130_fd_sc_hd__mux2_1 _451_ (.A0(\spi_byte[3] ),
    .A1(\sbuf[2] ),
    .S(_126_),
    .X(_148_));
 sky130_fd_sc_hd__mux2_1 _452_ (.A0(net73),
    .A1(_148_),
    .S(_144_),
    .X(_149_));
 sky130_fd_sc_hd__clkbuf_1 _453_ (.A(_149_),
    .X(_012_));
 sky130_fd_sc_hd__mux2_1 _454_ (.A0(\spi_byte[4] ),
    .A1(\sbuf[3] ),
    .S(_126_),
    .X(_150_));
 sky130_fd_sc_hd__mux2_1 _455_ (.A0(net75),
    .A1(_150_),
    .S(_144_),
    .X(_151_));
 sky130_fd_sc_hd__clkbuf_1 _456_ (.A(_151_),
    .X(_013_));
 sky130_fd_sc_hd__mux2_1 _457_ (.A0(\spi_byte[5] ),
    .A1(\sbuf[4] ),
    .S(_126_),
    .X(_152_));
 sky130_fd_sc_hd__mux2_1 _458_ (.A0(net65),
    .A1(_152_),
    .S(_144_),
    .X(_153_));
 sky130_fd_sc_hd__clkbuf_1 _459_ (.A(_153_),
    .X(_014_));
 sky130_fd_sc_hd__mux2_1 _460_ (.A0(\spi_byte[6] ),
    .A1(\sbuf[5] ),
    .S(\sst[1] ),
    .X(_154_));
 sky130_fd_sc_hd__mux2_1 _461_ (.A0(net60),
    .A1(_154_),
    .S(_144_),
    .X(_155_));
 sky130_fd_sc_hd__clkbuf_1 _462_ (.A(_155_),
    .X(_015_));
 sky130_fd_sc_hd__mux2_1 _463_ (.A0(\spi_byte[7] ),
    .A1(\sbuf[6] ),
    .S(\sst[1] ),
    .X(_156_));
 sky130_fd_sc_hd__mux2_1 _464_ (.A0(net72),
    .A1(_156_),
    .S(_144_),
    .X(_157_));
 sky130_fd_sc_hd__clkbuf_1 _465_ (.A(_157_),
    .X(_016_));
 sky130_fd_sc_hd__inv_2 _466_ (.A(\dmode[2] ),
    .Y(_158_));
 sky130_fd_sc_hd__or2b_1 _467_ (.A(\ip[1] ),
    .B_N(\ip[0] ),
    .X(_159_));
 sky130_fd_sc_hd__xor2_1 _468_ (.A(\ip[3] ),
    .B(\ip[1] ),
    .X(_160_));
 sky130_fd_sc_hd__a2111o_1 _469_ (.A1(\ip[2] ),
    .A2(_159_),
    .B1(_160_),
    .C1(\ip[4] ),
    .D1(_086_),
    .X(_161_));
 sky130_fd_sc_hd__a21oi_1 _470_ (.A1(_158_),
    .A2(_161_),
    .B1(_098_),
    .Y(_162_));
 sky130_fd_sc_hd__o21ai_1 _471_ (.A1(_137_),
    .A2(_162_),
    .B1(_133_),
    .Y(_163_));
 sky130_fd_sc_hd__nor2_1 _472_ (.A(\dmode[3] ),
    .B(_139_),
    .Y(_164_));
 sky130_fd_sc_hd__a211o_4 _473_ (.A1(_137_),
    .A2(_139_),
    .B1(_164_),
    .C1(_093_),
    .X(_165_));
 sky130_fd_sc_hd__mux2_1 _474_ (.A0(_163_),
    .A1(spi_dcbit),
    .S(_165_),
    .X(_166_));
 sky130_fd_sc_hd__clkbuf_1 _475_ (.A(_166_),
    .X(_017_));
 sky130_fd_sc_hd__clkbuf_4 _476_ (.A(pxhi),
    .X(_167_));
 sky130_fd_sc_hd__mux2_1 _477_ (.A0(net4),
    .A1(\pcolor_l[0] ),
    .S(_167_),
    .X(_168_));
 sky130_fd_sc_hd__buf_2 _478_ (.A(\ip[2] ),
    .X(_169_));
 sky130_fd_sc_hd__or2_1 _479_ (.A(_158_),
    .B(_096_),
    .X(_170_));
 sky130_fd_sc_hd__a211o_1 _480_ (.A1(_169_),
    .A2(_159_),
    .B1(_170_),
    .C1(_086_),
    .X(_171_));
 sky130_fd_sc_hd__or2b_1 _481_ (.A(\ip[2] ),
    .B_N(\ip[3] ),
    .X(_172_));
 sky130_fd_sc_hd__or2b_1 _482_ (.A(_089_),
    .B_N(_169_),
    .X(_173_));
 sky130_fd_sc_hd__a211o_1 _483_ (.A1(_172_),
    .A2(_173_),
    .B1(_085_),
    .C1(_095_),
    .X(_174_));
 sky130_fd_sc_hd__nand2_1 _484_ (.A(_171_),
    .B(_174_),
    .Y(_175_));
 sky130_fd_sc_hd__nor2_2 _485_ (.A(\dmode[3] ),
    .B(\ip[4] ),
    .Y(_176_));
 sky130_fd_sc_hd__a22o_1 _486_ (.A1(_122_),
    .A2(_168_),
    .B1(_175_),
    .B2(_176_),
    .X(_177_));
 sky130_fd_sc_hd__mux2_1 _487_ (.A0(_177_),
    .A1(net30),
    .S(_165_),
    .X(_178_));
 sky130_fd_sc_hd__clkbuf_1 _488_ (.A(_178_),
    .X(_018_));
 sky130_fd_sc_hd__mux2_1 _489_ (.A0(net5),
    .A1(\pcolor_l[1] ),
    .S(_167_),
    .X(_179_));
 sky130_fd_sc_hd__or3_1 _490_ (.A(_089_),
    .B(_095_),
    .C(_086_),
    .X(_180_));
 sky130_fd_sc_hd__o21a_1 _491_ (.A1(_159_),
    .A2(_172_),
    .B1(_180_),
    .X(_181_));
 sky130_fd_sc_hd__and2b_1 _492_ (.A_N(_090_),
    .B(\ip[2] ),
    .X(_182_));
 sky130_fd_sc_hd__nor2_1 _493_ (.A(_158_),
    .B(_089_),
    .Y(_183_));
 sky130_fd_sc_hd__a2bb2o_1 _494_ (.A1_N(_085_),
    .A2_N(_181_),
    .B1(_182_),
    .B2(_183_),
    .X(_184_));
 sky130_fd_sc_hd__a22o_1 _495_ (.A1(_122_),
    .A2(_179_),
    .B1(_184_),
    .B2(_176_),
    .X(_185_));
 sky130_fd_sc_hd__mux2_1 _496_ (.A0(_185_),
    .A1(net70),
    .S(_165_),
    .X(_186_));
 sky130_fd_sc_hd__clkbuf_1 _497_ (.A(_186_),
    .X(_019_));
 sky130_fd_sc_hd__mux2_1 _498_ (.A0(net6),
    .A1(\pcolor_l[2] ),
    .S(_167_),
    .X(_187_));
 sky130_fd_sc_hd__or3b_1 _499_ (.A(_089_),
    .B(_095_),
    .C_N(_182_),
    .X(_188_));
 sky130_fd_sc_hd__xnor2_2 _500_ (.A(_095_),
    .B(_090_),
    .Y(_189_));
 sky130_fd_sc_hd__or2_1 _501_ (.A(_172_),
    .B(_189_),
    .X(_190_));
 sky130_fd_sc_hd__a21oi_1 _502_ (.A1(_188_),
    .A2(_190_),
    .B1(_085_),
    .Y(_191_));
 sky130_fd_sc_hd__and3b_1 _503_ (.A_N(_189_),
    .B(_183_),
    .C(_169_),
    .X(_192_));
 sky130_fd_sc_hd__o21a_1 _504_ (.A1(_191_),
    .A2(_192_),
    .B1(_176_),
    .X(_193_));
 sky130_fd_sc_hd__a21o_1 _505_ (.A1(_122_),
    .A2(_187_),
    .B1(_193_),
    .X(_194_));
 sky130_fd_sc_hd__mux2_1 _506_ (.A0(_194_),
    .A1(net77),
    .S(_165_),
    .X(_195_));
 sky130_fd_sc_hd__clkbuf_1 _507_ (.A(_195_),
    .X(_020_));
 sky130_fd_sc_hd__mux2_1 _508_ (.A0(net2),
    .A1(\pcolor_l[3] ),
    .S(_167_),
    .X(_196_));
 sky130_fd_sc_hd__a21oi_1 _509_ (.A1(_169_),
    .A2(_189_),
    .B1(_089_),
    .Y(_197_));
 sky130_fd_sc_hd__a211o_1 _510_ (.A1(_180_),
    .A2(_190_),
    .B1(_085_),
    .C1(\ip[4] ),
    .X(_198_));
 sky130_fd_sc_hd__o311a_1 _511_ (.A1(\ip[4] ),
    .A2(_170_),
    .A3(_197_),
    .B1(_198_),
    .C1(_132_),
    .X(_199_));
 sky130_fd_sc_hd__o21ba_1 _512_ (.A1(_133_),
    .A2(_196_),
    .B1_N(_199_),
    .X(_200_));
 sky130_fd_sc_hd__mux2_1 _513_ (.A0(_200_),
    .A1(net81),
    .S(_165_),
    .X(_201_));
 sky130_fd_sc_hd__clkbuf_1 _514_ (.A(_201_),
    .X(_021_));
 sky130_fd_sc_hd__or2_1 _515_ (.A(_167_),
    .B(net3),
    .X(_202_));
 sky130_fd_sc_hd__or2b_1 _516_ (.A(\pcolor_l[4] ),
    .B_N(_167_),
    .X(_203_));
 sky130_fd_sc_hd__nand2_1 _517_ (.A(_095_),
    .B(_090_),
    .Y(_204_));
 sky130_fd_sc_hd__or2_1 _518_ (.A(_169_),
    .B(_095_),
    .X(_205_));
 sky130_fd_sc_hd__nor2_1 _519_ (.A(_159_),
    .B(_172_),
    .Y(_206_));
 sky130_fd_sc_hd__a32o_1 _520_ (.A1(_204_),
    .A2(_205_),
    .A3(_183_),
    .B1(_206_),
    .B2(_158_),
    .X(_207_));
 sky130_fd_sc_hd__a32o_1 _521_ (.A1(_122_),
    .A2(_202_),
    .A3(_203_),
    .B1(_207_),
    .B2(_176_),
    .X(_208_));
 sky130_fd_sc_hd__mux2_1 _522_ (.A0(_208_),
    .A1(net82),
    .S(_165_),
    .X(_209_));
 sky130_fd_sc_hd__clkbuf_1 _523_ (.A(_209_),
    .X(_022_));
 sky130_fd_sc_hd__mux2_1 _524_ (.A0(net4),
    .A1(\pcolor_l[5] ),
    .S(_167_),
    .X(_210_));
 sky130_fd_sc_hd__nor2_1 _525_ (.A(_089_),
    .B(_182_),
    .Y(_211_));
 sky130_fd_sc_hd__o311a_1 _526_ (.A1(\ip[4] ),
    .A2(_170_),
    .A3(_211_),
    .B1(_198_),
    .C1(_132_),
    .X(_212_));
 sky130_fd_sc_hd__o21ba_1 _527_ (.A1(_132_),
    .A2(_210_),
    .B1_N(_212_),
    .X(_213_));
 sky130_fd_sc_hd__mux2_1 _528_ (.A0(_213_),
    .A1(\spi_byte[5] ),
    .S(_165_),
    .X(_214_));
 sky130_fd_sc_hd__clkbuf_1 _529_ (.A(_214_),
    .X(_023_));
 sky130_fd_sc_hd__mux2_1 _530_ (.A0(net5),
    .A1(\pcolor_l[0] ),
    .S(_167_),
    .X(_215_));
 sky130_fd_sc_hd__and3b_1 _531_ (.A_N(_188_),
    .B(_158_),
    .C(_176_),
    .X(_216_));
 sky130_fd_sc_hd__a21o_1 _532_ (.A1(_122_),
    .A2(_215_),
    .B1(_216_),
    .X(_217_));
 sky130_fd_sc_hd__a41o_1 _533_ (.A1(_169_),
    .A2(_090_),
    .A3(_176_),
    .A4(_183_),
    .B1(_217_),
    .X(_218_));
 sky130_fd_sc_hd__mux2_1 _534_ (.A0(_218_),
    .A1(net78),
    .S(_165_),
    .X(_219_));
 sky130_fd_sc_hd__clkbuf_1 _535_ (.A(_219_),
    .X(_024_));
 sky130_fd_sc_hd__mux2_1 _536_ (.A0(net6),
    .A1(\pcolor_l[1] ),
    .S(_167_),
    .X(_220_));
 sky130_fd_sc_hd__a21o_1 _537_ (.A1(_122_),
    .A2(_220_),
    .B1(_216_),
    .X(_221_));
 sky130_fd_sc_hd__mux2_1 _538_ (.A0(_221_),
    .A1(net68),
    .S(_165_),
    .X(_222_));
 sky130_fd_sc_hd__clkbuf_1 _539_ (.A(_222_),
    .X(_025_));
 sky130_fd_sc_hd__inv_2 _540_ (.A(_090_),
    .Y(_223_));
 sky130_fd_sc_hd__a21oi_1 _541_ (.A1(_093_),
    .A2(_085_),
    .B1(_110_),
    .Y(_224_));
 sky130_fd_sc_hd__nand2_1 _542_ (.A(_136_),
    .B(_164_),
    .Y(_225_));
 sky130_fd_sc_hd__o221a_1 _543_ (.A1(_136_),
    .A2(_109_),
    .B1(_140_),
    .B2(_137_),
    .C1(_225_),
    .X(_226_));
 sky130_fd_sc_hd__inv_2 _544_ (.A(_086_),
    .Y(_227_));
 sky130_fd_sc_hd__a2111oi_2 _545_ (.A1(_158_),
    .A2(_161_),
    .B1(_227_),
    .C1(_093_),
    .D1(_098_),
    .Y(_228_));
 sky130_fd_sc_hd__or2b_1 _546_ (.A(_109_),
    .B_N(_228_),
    .X(_229_));
 sky130_fd_sc_hd__o2111a_1 _547_ (.A1(spi_done),
    .A2(_224_),
    .B1(_226_),
    .C1(_229_),
    .D1(_123_),
    .X(_230_));
 sky130_fd_sc_hd__a21o_1 _548_ (.A1(_093_),
    .A2(_085_),
    .B1(_110_),
    .X(_231_));
 sky130_fd_sc_hd__and3_1 _549_ (.A(spi_done),
    .B(_223_),
    .C(_231_),
    .X(_232_));
 sky130_fd_sc_hd__and3_1 _550_ (.A(_123_),
    .B(_229_),
    .C(_226_),
    .X(_233_));
 sky130_fd_sc_hd__a2bb2o_1 _551_ (.A1_N(_223_),
    .A2_N(_230_),
    .B1(_232_),
    .B2(_233_),
    .X(_026_));
 sky130_fd_sc_hd__inv_2 _552_ (.A(_095_),
    .Y(_234_));
 sky130_fd_sc_hd__a21oi_1 _553_ (.A1(spi_done),
    .A2(_231_),
    .B1(_228_),
    .Y(_235_));
 sky130_fd_sc_hd__nor2_1 _554_ (.A(_189_),
    .B(_235_),
    .Y(_236_));
 sky130_fd_sc_hd__a2bb2o_1 _555_ (.A1_N(_234_),
    .A2_N(_230_),
    .B1(_236_),
    .B2(_233_),
    .X(_027_));
 sky130_fd_sc_hd__and4_1 _556_ (.A(spi_done),
    .B(_169_),
    .C(_095_),
    .D(_090_),
    .X(_237_));
 sky130_fd_sc_hd__a31o_1 _557_ (.A1(spi_done),
    .A2(_095_),
    .A3(_090_),
    .B1(_169_),
    .X(_238_));
 sky130_fd_sc_hd__o21ai_1 _558_ (.A1(_093_),
    .A2(_110_),
    .B1(_238_),
    .Y(_239_));
 sky130_fd_sc_hd__o2bb2a_1 _559_ (.A1_N(_091_),
    .A2_N(_228_),
    .B1(_237_),
    .B2(_239_),
    .X(_240_));
 sky130_fd_sc_hd__o21ba_1 _560_ (.A1(_110_),
    .A2(_085_),
    .B1_N(_240_),
    .X(_241_));
 sky130_fd_sc_hd__mux2_1 _561_ (.A0(_169_),
    .A1(_241_),
    .S(_233_),
    .X(_242_));
 sky130_fd_sc_hd__clkbuf_1 _562_ (.A(_242_),
    .X(_028_));
 sky130_fd_sc_hd__a21o_1 _563_ (.A1(_089_),
    .A2(_237_),
    .B1(_224_),
    .X(_243_));
 sky130_fd_sc_hd__and4_1 _564_ (.A(_123_),
    .B(_229_),
    .C(_226_),
    .D(_237_),
    .X(_244_));
 sky130_fd_sc_hd__o2bb2a_1 _565_ (.A1_N(_233_),
    .A2_N(_243_),
    .B1(_244_),
    .B2(_089_),
    .X(_029_));
 sky130_fd_sc_hd__inv_2 _566_ (.A(\ip[4] ),
    .Y(_245_));
 sky130_fd_sc_hd__and4_1 _567_ (.A(_089_),
    .B(_245_),
    .C(_231_),
    .D(_237_),
    .X(_246_));
 sky130_fd_sc_hd__a41o_1 _568_ (.A1(_123_),
    .A2(_229_),
    .A3(_226_),
    .A4(_243_),
    .B1(_245_),
    .X(_247_));
 sky130_fd_sc_hd__a21bo_1 _569_ (.A1(_233_),
    .A2(_246_),
    .B1_N(_247_),
    .X(_030_));
 sky130_fd_sc_hd__nor2_1 _570_ (.A(\dmode[2] ),
    .B(\dmode[0] ),
    .Y(_248_));
 sky130_fd_sc_hd__o41a_1 _571_ (.A1(\ip[3] ),
    .A2(_169_),
    .A3(_223_),
    .A4(\ip[4] ),
    .B1(\dmode[2] ),
    .X(_249_));
 sky130_fd_sc_hd__a211o_4 _572_ (.A1(_093_),
    .A2(_085_),
    .B1(_248_),
    .C1(_249_),
    .X(_250_));
 sky130_fd_sc_hd__nor2_4 _573_ (.A(_109_),
    .B(_250_),
    .Y(_251_));
 sky130_fd_sc_hd__mux2_1 _574_ (.A0(_251_),
    .A1(_250_),
    .S(\dcnt[0] ),
    .X(_252_));
 sky130_fd_sc_hd__clkbuf_1 _575_ (.A(_252_),
    .X(_031_));
 sky130_fd_sc_hd__a211oi_2 _576_ (.A1(_093_),
    .A2(_085_),
    .B1(_248_),
    .C1(_249_),
    .Y(_253_));
 sky130_fd_sc_hd__and3_1 _577_ (.A(\dcnt[1] ),
    .B(\dcnt[0] ),
    .C(_253_),
    .X(_254_));
 sky130_fd_sc_hd__buf_2 _578_ (.A(_253_),
    .X(_255_));
 sky130_fd_sc_hd__a21oi_1 _579_ (.A1(\dcnt[0] ),
    .A2(_255_),
    .B1(net45),
    .Y(_256_));
 sky130_fd_sc_hd__nor2_1 _580_ (.A(_254_),
    .B(net46),
    .Y(_032_));
 sky130_fd_sc_hd__xor2_1 _581_ (.A(net35),
    .B(_254_),
    .X(_033_));
 sky130_fd_sc_hd__and2_1 _582_ (.A(\dcnt[2] ),
    .B(_254_),
    .X(_257_));
 sky130_fd_sc_hd__and4_1 _583_ (.A(\dcnt[1] ),
    .B(\dcnt[0] ),
    .C(\dcnt[3] ),
    .D(\dcnt[2] ),
    .X(_258_));
 sky130_fd_sc_hd__nand2_1 _584_ (.A(_255_),
    .B(_258_),
    .Y(_259_));
 sky130_fd_sc_hd__o21a_1 _585_ (.A1(net32),
    .A2(_257_),
    .B1(_259_),
    .X(_034_));
 sky130_fd_sc_hd__xnor2_1 _586_ (.A(net36),
    .B(_259_),
    .Y(_035_));
 sky130_fd_sc_hd__and2_1 _587_ (.A(\dcnt[5] ),
    .B(\dcnt[4] ),
    .X(_260_));
 sky130_fd_sc_hd__and2_1 _588_ (.A(_258_),
    .B(_260_),
    .X(_261_));
 sky130_fd_sc_hd__and2_1 _589_ (.A(_255_),
    .B(_261_),
    .X(_262_));
 sky130_fd_sc_hd__a31o_1 _590_ (.A1(\dcnt[4] ),
    .A2(_253_),
    .A3(_258_),
    .B1(\dcnt[5] ),
    .X(_263_));
 sky130_fd_sc_hd__and2b_1 _591_ (.A_N(_262_),
    .B(_263_),
    .X(_264_));
 sky130_fd_sc_hd__clkbuf_1 _592_ (.A(_264_),
    .X(_036_));
 sky130_fd_sc_hd__and3_1 _593_ (.A(\dcnt[6] ),
    .B(_253_),
    .C(_261_),
    .X(_265_));
 sky130_fd_sc_hd__a21o_1 _594_ (.A1(_109_),
    .A2(_255_),
    .B1(_265_),
    .X(_266_));
 sky130_fd_sc_hd__o21ba_1 _595_ (.A1(net55),
    .A2(_262_),
    .B1_N(_266_),
    .X(_037_));
 sky130_fd_sc_hd__and4_1 _596_ (.A(\dcnt[7] ),
    .B(\dcnt[6] ),
    .C(_258_),
    .D(_260_),
    .X(_267_));
 sky130_fd_sc_hd__clkbuf_2 _597_ (.A(_267_),
    .X(_268_));
 sky130_fd_sc_hd__o2bb2a_1 _598_ (.A1_N(_255_),
    .A2_N(_268_),
    .B1(_265_),
    .B2(net44),
    .X(_038_));
 sky130_fd_sc_hd__xor2_1 _599_ (.A(\dcnt[8] ),
    .B(_268_),
    .X(_269_));
 sky130_fd_sc_hd__a22o_1 _600_ (.A1(net64),
    .A2(_250_),
    .B1(_251_),
    .B2(_269_),
    .X(_039_));
 sky130_fd_sc_hd__a21o_1 _601_ (.A1(\dcnt[8] ),
    .A2(_268_),
    .B1(\dcnt[9] ),
    .X(_270_));
 sky130_fd_sc_hd__nand2_1 _602_ (.A(_101_),
    .B(_268_),
    .Y(_271_));
 sky130_fd_sc_hd__a32o_1 _603_ (.A1(_251_),
    .A2(_270_),
    .A3(_271_),
    .B1(_250_),
    .B2(net33),
    .X(_040_));
 sky130_fd_sc_hd__and2_1 _604_ (.A(\dcnt[7] ),
    .B(\dcnt[6] ),
    .X(_272_));
 sky130_fd_sc_hd__and4_1 _605_ (.A(_101_),
    .B(_258_),
    .C(_260_),
    .D(_272_),
    .X(_273_));
 sky130_fd_sc_hd__nand2_1 _606_ (.A(\dcnt[10] ),
    .B(_273_),
    .Y(_274_));
 sky130_fd_sc_hd__a22o_1 _607_ (.A1(\dcnt[10] ),
    .A2(_250_),
    .B1(_251_),
    .B2(_274_),
    .X(_275_));
 sky130_fd_sc_hd__o21a_1 _608_ (.A1(net66),
    .A2(_273_),
    .B1(_275_),
    .X(_041_));
 sky130_fd_sc_hd__and3_1 _609_ (.A(\dcnt[10] ),
    .B(_255_),
    .C(_273_),
    .X(_276_));
 sky130_fd_sc_hd__xor2_1 _610_ (.A(net43),
    .B(_276_),
    .X(_042_));
 sky130_fd_sc_hd__and3_1 _611_ (.A(\dcnt[11] ),
    .B(\dcnt[10] ),
    .C(_273_),
    .X(_277_));
 sky130_fd_sc_hd__or2_1 _612_ (.A(\dcnt[12] ),
    .B(_277_),
    .X(_278_));
 sky130_fd_sc_hd__nand2_1 _613_ (.A(\dcnt[12] ),
    .B(_277_),
    .Y(_279_));
 sky130_fd_sc_hd__a32o_1 _614_ (.A1(_251_),
    .A2(_278_),
    .A3(_279_),
    .B1(_250_),
    .B2(net54),
    .X(_043_));
 sky130_fd_sc_hd__and3_1 _615_ (.A(\dcnt[11] ),
    .B(\dcnt[10] ),
    .C(_101_),
    .X(_280_));
 sky130_fd_sc_hd__a31o_1 _616_ (.A1(\dcnt[12] ),
    .A2(_268_),
    .A3(_280_),
    .B1(\dcnt[13] ),
    .X(_281_));
 sky130_fd_sc_hd__nand3_1 _617_ (.A(\dcnt[13] ),
    .B(\dcnt[12] ),
    .C(_277_),
    .Y(_282_));
 sky130_fd_sc_hd__a32o_1 _618_ (.A1(_251_),
    .A2(_281_),
    .A3(_282_),
    .B1(_250_),
    .B2(net56),
    .X(_044_));
 sky130_fd_sc_hd__a31o_1 _619_ (.A1(\dcnt[13] ),
    .A2(\dcnt[12] ),
    .A3(_277_),
    .B1(\dcnt[14] ),
    .X(_283_));
 sky130_fd_sc_hd__and4_1 _620_ (.A(\dcnt[11] ),
    .B(\dcnt[10] ),
    .C(_106_),
    .D(_273_),
    .X(_284_));
 sky130_fd_sc_hd__inv_2 _621_ (.A(_284_),
    .Y(_285_));
 sky130_fd_sc_hd__a32o_1 _622_ (.A1(_251_),
    .A2(_283_),
    .A3(_285_),
    .B1(_250_),
    .B2(net34),
    .X(_045_));
 sky130_fd_sc_hd__nand2_1 _623_ (.A(_255_),
    .B(_284_),
    .Y(_286_));
 sky130_fd_sc_hd__xnor2_1 _624_ (.A(net50),
    .B(_286_),
    .Y(_046_));
 sky130_fd_sc_hd__and4_1 _625_ (.A(\dcnt[15] ),
    .B(_106_),
    .C(_268_),
    .D(_280_),
    .X(_287_));
 sky130_fd_sc_hd__or2_1 _626_ (.A(\dcnt[16] ),
    .B(_287_),
    .X(_288_));
 sky130_fd_sc_hd__nand3_1 _627_ (.A(\dcnt[15] ),
    .B(\dcnt[16] ),
    .C(_284_),
    .Y(_289_));
 sky130_fd_sc_hd__a32o_1 _628_ (.A1(_251_),
    .A2(_288_),
    .A3(_289_),
    .B1(_250_),
    .B2(net42),
    .X(_047_));
 sky130_fd_sc_hd__inv_2 _629_ (.A(\dcnt[17] ),
    .Y(_290_));
 sky130_fd_sc_hd__and3_1 _630_ (.A(\dcnt[15] ),
    .B(_100_),
    .C(_284_),
    .X(_291_));
 sky130_fd_sc_hd__a21oi_1 _631_ (.A1(_290_),
    .A2(_289_),
    .B1(_291_),
    .Y(_292_));
 sky130_fd_sc_hd__a22o_1 _632_ (.A1(net49),
    .A2(_250_),
    .B1(_251_),
    .B2(_292_),
    .X(_048_));
 sky130_fd_sc_hd__and2_1 _633_ (.A(_255_),
    .B(_291_),
    .X(_293_));
 sky130_fd_sc_hd__xor2_1 _634_ (.A(net38),
    .B(_293_),
    .X(_049_));
 sky130_fd_sc_hd__a31o_1 _635_ (.A1(\dcnt[18] ),
    .A2(_255_),
    .A3(_291_),
    .B1(\dcnt[19] ),
    .X(_294_));
 sky130_fd_sc_hd__and4_1 _636_ (.A(\dcnt[18] ),
    .B(\dcnt[19] ),
    .C(_100_),
    .D(_287_),
    .X(_295_));
 sky130_fd_sc_hd__o21ai_1 _637_ (.A1(_109_),
    .A2(_295_),
    .B1(_255_),
    .Y(_296_));
 sky130_fd_sc_hd__and2_1 _638_ (.A(_294_),
    .B(_296_),
    .X(_297_));
 sky130_fd_sc_hd__clkbuf_1 _639_ (.A(_297_),
    .X(_050_));
 sky130_fd_sc_hd__and2_1 _640_ (.A(_251_),
    .B(_295_),
    .X(_298_));
 sky130_fd_sc_hd__mux2_1 _641_ (.A0(_298_),
    .A1(_296_),
    .S(net83),
    .X(_299_));
 sky130_fd_sc_hd__clkbuf_1 _642_ (.A(_299_),
    .X(_051_));
 sky130_fd_sc_hd__nand2_1 _643_ (.A(sending),
    .B(spi_done),
    .Y(_300_));
 sky130_fd_sc_hd__a21bo_1 _644_ (.A1(\dmode[3] ),
    .A2(_300_),
    .B1_N(net9),
    .X(_301_));
 sky130_fd_sc_hd__nor2_2 _645_ (.A(_132_),
    .B(pxhi),
    .Y(_302_));
 sky130_fd_sc_hd__a211o_2 _646_ (.A1(_110_),
    .A2(_130_),
    .B1(_301_),
    .C1(_302_),
    .X(_303_));
 sky130_fd_sc_hd__nor2_1 _647_ (.A(_138_),
    .B(_303_),
    .Y(_304_));
 sky130_fd_sc_hd__mux2_1 _648_ (.A0(_304_),
    .A1(_303_),
    .S(\px[0] ),
    .X(_305_));
 sky130_fd_sc_hd__clkbuf_1 _649_ (.A(_305_),
    .X(_052_));
 sky130_fd_sc_hd__a211oi_4 _650_ (.A1(_110_),
    .A2(_130_),
    .B1(_301_),
    .C1(_302_),
    .Y(_306_));
 sky130_fd_sc_hd__clkbuf_4 _651_ (.A(_306_),
    .X(_307_));
 sky130_fd_sc_hd__a21o_1 _652_ (.A1(\px[0] ),
    .A2(_307_),
    .B1(\px[1] ),
    .X(_308_));
 sky130_fd_sc_hd__nand2_2 _653_ (.A(_133_),
    .B(_307_),
    .Y(_309_));
 sky130_fd_sc_hd__nand3_1 _654_ (.A(\px[1] ),
    .B(\px[0] ),
    .C(_307_),
    .Y(_310_));
 sky130_fd_sc_hd__and3_1 _655_ (.A(_308_),
    .B(_309_),
    .C(_310_),
    .X(_311_));
 sky130_fd_sc_hd__clkbuf_1 _656_ (.A(_311_),
    .X(_053_));
 sky130_fd_sc_hd__inv_2 _657_ (.A(net48),
    .Y(_312_));
 sky130_fd_sc_hd__and3_1 _658_ (.A(\px[1] ),
    .B(\px[0] ),
    .C(\px[2] ),
    .X(_313_));
 sky130_fd_sc_hd__buf_2 _659_ (.A(_306_),
    .X(_314_));
 sky130_fd_sc_hd__o21a_1 _660_ (.A1(_133_),
    .A2(_313_),
    .B1(_314_),
    .X(_315_));
 sky130_fd_sc_hd__a21oi_1 _661_ (.A1(_312_),
    .A2(_310_),
    .B1(_315_),
    .Y(_054_));
 sky130_fd_sc_hd__a21o_1 _662_ (.A1(_313_),
    .A2(_307_),
    .B1(\px[3] ),
    .X(_316_));
 sky130_fd_sc_hd__nand2_1 _663_ (.A(_112_),
    .B(_314_),
    .Y(_317_));
 sky130_fd_sc_hd__and3_1 _664_ (.A(_309_),
    .B(_316_),
    .C(_317_),
    .X(_318_));
 sky130_fd_sc_hd__clkbuf_1 _665_ (.A(_318_),
    .X(_055_));
 sky130_fd_sc_hd__inv_2 _666_ (.A(net51),
    .Y(_319_));
 sky130_fd_sc_hd__and2_1 _667_ (.A(\px[4] ),
    .B(_112_),
    .X(_320_));
 sky130_fd_sc_hd__o21a_1 _668_ (.A1(_133_),
    .A2(_320_),
    .B1(_314_),
    .X(_321_));
 sky130_fd_sc_hd__a21oi_1 _669_ (.A1(_319_),
    .A2(_317_),
    .B1(_321_),
    .Y(_056_));
 sky130_fd_sc_hd__a21o_1 _670_ (.A1(_320_),
    .A2(_306_),
    .B1(\px[5] ),
    .X(_322_));
 sky130_fd_sc_hd__nand3_1 _671_ (.A(\px[5] ),
    .B(_320_),
    .C(_307_),
    .Y(_323_));
 sky130_fd_sc_hd__and3_1 _672_ (.A(_309_),
    .B(_322_),
    .C(_323_),
    .X(_324_));
 sky130_fd_sc_hd__clkbuf_1 _673_ (.A(_324_),
    .X(_057_));
 sky130_fd_sc_hd__inv_2 _674_ (.A(net59),
    .Y(_325_));
 sky130_fd_sc_hd__and4_1 _675_ (.A(\px[5] ),
    .B(\px[6] ),
    .C(_320_),
    .D(_307_),
    .X(_326_));
 sky130_fd_sc_hd__a221oi_1 _676_ (.A1(_133_),
    .A2(_314_),
    .B1(_323_),
    .B2(_325_),
    .C1(_326_),
    .Y(_058_));
 sky130_fd_sc_hd__o221a_1 _677_ (.A1(_114_),
    .A2(_303_),
    .B1(_326_),
    .B2(net39),
    .C1(_309_),
    .X(_059_));
 sky130_fd_sc_hd__nor2_1 _678_ (.A(_114_),
    .B(_303_),
    .Y(_327_));
 sky130_fd_sc_hd__and3_1 _679_ (.A(\px[8] ),
    .B(_112_),
    .C(_113_),
    .X(_328_));
 sky130_fd_sc_hd__o21ai_1 _680_ (.A1(_133_),
    .A2(_328_),
    .B1(_314_),
    .Y(_329_));
 sky130_fd_sc_hd__o21a_1 _681_ (.A1(net40),
    .A2(_327_),
    .B1(_329_),
    .X(_060_));
 sky130_fd_sc_hd__and3_1 _682_ (.A(_122_),
    .B(_306_),
    .C(_328_),
    .X(_330_));
 sky130_fd_sc_hd__mux2_1 _683_ (.A0(_330_),
    .A1(_329_),
    .S(\px[9] ),
    .X(_331_));
 sky130_fd_sc_hd__clkbuf_1 _684_ (.A(_331_),
    .X(_061_));
 sky130_fd_sc_hd__nor2_1 _685_ (.A(_132_),
    .B(_131_),
    .Y(_332_));
 sky130_fd_sc_hd__nand3_1 _686_ (.A(\px[9] ),
    .B(\px[10] ),
    .C(_328_),
    .Y(_333_));
 sky130_fd_sc_hd__a21o_1 _687_ (.A1(_332_),
    .A2(_333_),
    .B1(_303_),
    .X(_334_));
 sky130_fd_sc_hd__a31o_1 _688_ (.A1(\px[9] ),
    .A2(_306_),
    .A3(_328_),
    .B1(\px[10] ),
    .X(_335_));
 sky130_fd_sc_hd__and2_1 _689_ (.A(_334_),
    .B(_335_),
    .X(_336_));
 sky130_fd_sc_hd__clkbuf_1 _690_ (.A(_336_),
    .X(_062_));
 sky130_fd_sc_hd__nor2_1 _691_ (.A(\px[11] ),
    .B(_333_),
    .Y(_337_));
 sky130_fd_sc_hd__a32o_1 _692_ (.A1(_314_),
    .A2(_332_),
    .A3(_337_),
    .B1(_334_),
    .B2(net41),
    .X(_063_));
 sky130_fd_sc_hd__and4_1 _693_ (.A(\px[9] ),
    .B(\px[10] ),
    .C(\px[11] ),
    .D(_328_),
    .X(_338_));
 sky130_fd_sc_hd__a21o_1 _694_ (.A1(_307_),
    .A2(_338_),
    .B1(\px[12] ),
    .X(_339_));
 sky130_fd_sc_hd__nand3_1 _695_ (.A(\px[12] ),
    .B(_307_),
    .C(_338_),
    .Y(_340_));
 sky130_fd_sc_hd__and3_1 _696_ (.A(_309_),
    .B(_339_),
    .C(_340_),
    .X(_341_));
 sky130_fd_sc_hd__clkbuf_1 _697_ (.A(_341_),
    .X(_064_));
 sky130_fd_sc_hd__or2_1 _698_ (.A(_132_),
    .B(_131_),
    .X(_342_));
 sky130_fd_sc_hd__and3_1 _699_ (.A(\px[12] ),
    .B(\px[13] ),
    .C(_338_),
    .X(_343_));
 sky130_fd_sc_hd__o21a_1 _700_ (.A1(_342_),
    .A2(_343_),
    .B1(_314_),
    .X(_344_));
 sky130_fd_sc_hd__a21oi_1 _701_ (.A1(_115_),
    .A2(_340_),
    .B1(_344_),
    .Y(_065_));
 sky130_fd_sc_hd__a21oi_1 _702_ (.A1(_314_),
    .A2(_343_),
    .B1(net47),
    .Y(_345_));
 sky130_fd_sc_hd__and4_1 _703_ (.A(\px[12] ),
    .B(\px[13] ),
    .C(\px[14] ),
    .D(_338_),
    .X(_346_));
 sky130_fd_sc_hd__o21a_1 _704_ (.A1(_133_),
    .A2(_346_),
    .B1(_314_),
    .X(_347_));
 sky130_fd_sc_hd__nor2_1 _705_ (.A(_345_),
    .B(_347_),
    .Y(_066_));
 sky130_fd_sc_hd__a21o_1 _706_ (.A1(_307_),
    .A2(_346_),
    .B1(\px[15] ),
    .X(_348_));
 sky130_fd_sc_hd__nand3_1 _707_ (.A(\px[15] ),
    .B(_307_),
    .C(_346_),
    .Y(_349_));
 sky130_fd_sc_hd__and3_1 _708_ (.A(_309_),
    .B(_348_),
    .C(_349_),
    .X(_350_));
 sky130_fd_sc_hd__clkbuf_1 _709_ (.A(_350_),
    .X(_067_));
 sky130_fd_sc_hd__inv_2 _710_ (.A(net57),
    .Y(_351_));
 sky130_fd_sc_hd__a31o_1 _711_ (.A1(\px[15] ),
    .A2(\px[16] ),
    .A3(_346_),
    .B1(_342_),
    .X(_352_));
 sky130_fd_sc_hd__a22oi_1 _712_ (.A1(_351_),
    .A2(_349_),
    .B1(_352_),
    .B2(_314_),
    .Y(_068_));
 sky130_fd_sc_hd__a21oi_1 _713_ (.A1(_110_),
    .A2(_130_),
    .B1(_301_),
    .Y(_353_));
 sky130_fd_sc_hd__o21a_1 _714_ (.A1(_167_),
    .A2(_353_),
    .B1(_303_),
    .X(_069_));
 sky130_fd_sc_hd__a22o_1 _715_ (.A1(_122_),
    .A2(_300_),
    .B1(_164_),
    .B2(_093_),
    .X(_354_));
 sky130_fd_sc_hd__a31o_1 _716_ (.A1(_130_),
    .A2(_300_),
    .A3(_139_),
    .B1(_354_),
    .X(_070_));
 sky130_fd_sc_hd__nand2_2 _717_ (.A(_138_),
    .B(_302_),
    .Y(_355_));
 sky130_fd_sc_hd__inv_2 _718_ (.A(_355_),
    .Y(_356_));
 sky130_fd_sc_hd__o32a_1 _719_ (.A1(_093_),
    .A2(_133_),
    .A3(_202_),
    .B1(_356_),
    .B2(net29),
    .X(_071_));
 sky130_fd_sc_hd__mux2_1 _720_ (.A0(net4),
    .A1(net71),
    .S(_355_),
    .X(_357_));
 sky130_fd_sc_hd__clkbuf_1 _721_ (.A(_357_),
    .X(_072_));
 sky130_fd_sc_hd__mux2_1 _722_ (.A0(net5),
    .A1(net74),
    .S(_355_),
    .X(_358_));
 sky130_fd_sc_hd__clkbuf_1 _723_ (.A(_358_),
    .X(_073_));
 sky130_fd_sc_hd__mux2_1 _724_ (.A0(net6),
    .A1(net67),
    .S(_355_),
    .X(_359_));
 sky130_fd_sc_hd__clkbuf_1 _725_ (.A(_359_),
    .X(_074_));
 sky130_fd_sc_hd__mux2_1 _726_ (.A0(net1),
    .A1(net76),
    .S(_355_),
    .X(_360_));
 sky130_fd_sc_hd__clkbuf_1 _727_ (.A(_360_),
    .X(_075_));
 sky130_fd_sc_hd__mux2_1 _728_ (.A0(net2),
    .A1(\pcolor_l[0] ),
    .S(_355_),
    .X(_361_));
 sky130_fd_sc_hd__clkbuf_1 _729_ (.A(_361_),
    .X(_076_));
 sky130_fd_sc_hd__o31ai_1 _730_ (.A1(\sst[0] ),
    .A2(\sst[3] ),
    .A3(\sst[2] ),
    .B1(_124_),
    .Y(_362_));
 sky130_fd_sc_hd__and2_1 _731_ (.A(_126_),
    .B(_124_),
    .X(_363_));
 sky130_fd_sc_hd__a21o_1 _732_ (.A1(net28),
    .A2(_362_),
    .B1(_363_),
    .X(_077_));
 sky130_fd_sc_hd__mux2_1 _733_ (.A0(net13),
    .A1(net72),
    .S(\sst[2] ),
    .X(_364_));
 sky130_fd_sc_hd__clkbuf_1 _734_ (.A(_364_),
    .X(_078_));
 sky130_fd_sc_hd__and2_1 _735_ (.A(net80),
    .B(_129_),
    .X(_365_));
 sky130_fd_sc_hd__clkbuf_1 _736_ (.A(_365_),
    .X(_079_));
 sky130_fd_sc_hd__mux2_1 _737_ (.A0(spi_dcbit),
    .A1(net12),
    .S(_129_),
    .X(_366_));
 sky130_fd_sc_hd__clkbuf_1 _738_ (.A(_366_),
    .X(_080_));
 sky130_fd_sc_hd__or2_1 _739_ (.A(_003_),
    .B(_141_),
    .X(_367_));
 sky130_fd_sc_hd__mux2_1 _740_ (.A0(_363_),
    .A1(_367_),
    .S(\sbit[0] ),
    .X(_368_));
 sky130_fd_sc_hd__clkbuf_1 _741_ (.A(_368_),
    .X(_081_));
 sky130_fd_sc_hd__a21oi_1 _742_ (.A1(\sbit[1] ),
    .A2(\sbit[0] ),
    .B1(_127_),
    .Y(_369_));
 sky130_fd_sc_hd__a21o_1 _743_ (.A1(\sbit[0] ),
    .A2(_144_),
    .B1(net79),
    .X(_370_));
 sky130_fd_sc_hd__o21a_1 _744_ (.A1(_367_),
    .A2(_369_),
    .B1(_370_),
    .X(_082_));
 sky130_fd_sc_hd__a31o_1 _745_ (.A1(\sbit[1] ),
    .A2(\sbit[0] ),
    .A3(_144_),
    .B1(net52),
    .X(_371_));
 sky130_fd_sc_hd__o21a_1 _746_ (.A1(_126_),
    .A2(_141_),
    .B1(_371_),
    .X(_083_));
 sky130_fd_sc_hd__dfstp_1 _747_ (.CLK(clknet_3_3__leaf_clk),
    .D(_002_),
    .SET_B(net18),
    .Q(\dmode[0] ));
 sky130_fd_sc_hd__dfrtp_1 _748_ (.CLK(clknet_3_3__leaf_clk),
    .D(_004_),
    .RESET_B(net16),
    .Q(\dmode[1] ));
 sky130_fd_sc_hd__dfrtp_4 _749_ (.CLK(clknet_3_3__leaf_clk),
    .D(_005_),
    .RESET_B(net18),
    .Q(\dmode[2] ));
 sky130_fd_sc_hd__dfrtp_4 _750_ (.CLK(clknet_3_1__leaf_clk),
    .D(_006_),
    .RESET_B(net16),
    .Q(\dmode[3] ));
 sky130_fd_sc_hd__dfstp_2 _751_ (.CLK(clknet_3_7__leaf_clk),
    .D(_007_),
    .SET_B(net21),
    .Q(\sst[0] ));
 sky130_fd_sc_hd__dfrtp_2 _752_ (.CLK(clknet_3_7__leaf_clk),
    .D(net27),
    .RESET_B(net25),
    .Q(\sst[1] ));
 sky130_fd_sc_hd__dfrtp_1 _753_ (.CLK(clknet_3_7__leaf_clk),
    .D(net62),
    .RESET_B(net25),
    .Q(\sst[2] ));
 sky130_fd_sc_hd__dfrtp_1 _754_ (.CLK(clknet_3_7__leaf_clk),
    .D(_003_),
    .RESET_B(net25),
    .Q(\sst[3] ));
 sky130_fd_sc_hd__dfrtp_1 _755_ (.CLK(clknet_3_5__leaf_clk),
    .D(net31),
    .RESET_B(net21),
    .Q(\sbuf[0] ));
 sky130_fd_sc_hd__dfrtp_1 _756_ (.CLK(clknet_3_5__leaf_clk),
    .D(_010_),
    .RESET_B(net21),
    .Q(\sbuf[1] ));
 sky130_fd_sc_hd__dfrtp_1 _757_ (.CLK(clknet_3_5__leaf_clk),
    .D(_011_),
    .RESET_B(net21),
    .Q(\sbuf[2] ));
 sky130_fd_sc_hd__dfrtp_1 _758_ (.CLK(clknet_3_5__leaf_clk),
    .D(_012_),
    .RESET_B(net21),
    .Q(\sbuf[3] ));
 sky130_fd_sc_hd__dfrtp_1 _759_ (.CLK(clknet_3_5__leaf_clk),
    .D(_013_),
    .RESET_B(net21),
    .Q(\sbuf[4] ));
 sky130_fd_sc_hd__dfrtp_1 _760_ (.CLK(clknet_3_5__leaf_clk),
    .D(_014_),
    .RESET_B(net22),
    .Q(\sbuf[5] ));
 sky130_fd_sc_hd__dfrtp_1 _761_ (.CLK(clknet_3_5__leaf_clk),
    .D(_015_),
    .RESET_B(net22),
    .Q(\sbuf[6] ));
 sky130_fd_sc_hd__dfrtp_1 _762_ (.CLK(clknet_3_6__leaf_clk),
    .D(_016_),
    .RESET_B(net25),
    .Q(\sbuf[7] ));
 sky130_fd_sc_hd__dfrtp_1 _763_ (.CLK(clknet_3_0__leaf_clk),
    .D(_001_),
    .RESET_B(net15),
    .Q(net10));
 sky130_fd_sc_hd__dfrtp_1 _764_ (.CLK(clknet_3_5__leaf_clk),
    .D(_000_),
    .RESET_B(net21),
    .Q(net8));
 sky130_fd_sc_hd__dfrtp_1 _765_ (.CLK(clknet_3_7__leaf_clk),
    .D(_372_),
    .RESET_B(net22),
    .Q(spi_start));
 sky130_fd_sc_hd__dfstp_1 _766_ (.CLK(clknet_3_2__leaf_clk),
    .D(_017_),
    .SET_B(net19),
    .Q(spi_dcbit));
 sky130_fd_sc_hd__dfrtp_1 _767_ (.CLK(clknet_3_5__leaf_clk),
    .D(_018_),
    .RESET_B(net22),
    .Q(\spi_byte[0] ));
 sky130_fd_sc_hd__dfrtp_1 _768_ (.CLK(clknet_3_5__leaf_clk),
    .D(_019_),
    .RESET_B(net22),
    .Q(\spi_byte[1] ));
 sky130_fd_sc_hd__dfrtp_1 _769_ (.CLK(clknet_3_4__leaf_clk),
    .D(_020_),
    .RESET_B(net21),
    .Q(\spi_byte[2] ));
 sky130_fd_sc_hd__dfrtp_1 _770_ (.CLK(clknet_3_5__leaf_clk),
    .D(_021_),
    .RESET_B(net21),
    .Q(\spi_byte[3] ));
 sky130_fd_sc_hd__dfrtp_1 _771_ (.CLK(clknet_3_4__leaf_clk),
    .D(_022_),
    .RESET_B(net21),
    .Q(\spi_byte[4] ));
 sky130_fd_sc_hd__dfrtp_1 _772_ (.CLK(clknet_3_1__leaf_clk),
    .D(_023_),
    .RESET_B(net16),
    .Q(\spi_byte[5] ));
 sky130_fd_sc_hd__dfrtp_1 _773_ (.CLK(clknet_3_4__leaf_clk),
    .D(_024_),
    .RESET_B(net22),
    .Q(\spi_byte[6] ));
 sky130_fd_sc_hd__dfrtp_1 _774_ (.CLK(clknet_3_4__leaf_clk),
    .D(_025_),
    .RESET_B(net22),
    .Q(\spi_byte[7] ));
 sky130_fd_sc_hd__dfrtp_1 _775_ (.CLK(clknet_3_6__leaf_clk),
    .D(_026_),
    .RESET_B(net24),
    .Q(\ip[0] ));
 sky130_fd_sc_hd__dfrtp_2 _776_ (.CLK(clknet_3_6__leaf_clk),
    .D(_027_),
    .RESET_B(net24),
    .Q(\ip[1] ));
 sky130_fd_sc_hd__dfrtp_4 _777_ (.CLK(clknet_3_6__leaf_clk),
    .D(_028_),
    .RESET_B(net24),
    .Q(\ip[2] ));
 sky130_fd_sc_hd__dfrtp_2 _778_ (.CLK(clknet_3_6__leaf_clk),
    .D(_029_),
    .RESET_B(net24),
    .Q(\ip[3] ));
 sky130_fd_sc_hd__dfrtp_4 _779_ (.CLK(clknet_3_3__leaf_clk),
    .D(_030_),
    .RESET_B(net24),
    .Q(\ip[4] ));
 sky130_fd_sc_hd__dfrtp_1 _780_ (.CLK(clknet_3_3__leaf_clk),
    .D(_031_),
    .RESET_B(net18),
    .Q(\dcnt[0] ));
 sky130_fd_sc_hd__dfrtp_1 _781_ (.CLK(clknet_3_3__leaf_clk),
    .D(_032_),
    .RESET_B(net18),
    .Q(\dcnt[1] ));
 sky130_fd_sc_hd__dfrtp_1 _782_ (.CLK(clknet_3_6__leaf_clk),
    .D(_033_),
    .RESET_B(net24),
    .Q(\dcnt[2] ));
 sky130_fd_sc_hd__dfrtp_1 _783_ (.CLK(clknet_3_6__leaf_clk),
    .D(_034_),
    .RESET_B(net24),
    .Q(\dcnt[3] ));
 sky130_fd_sc_hd__dfrtp_1 _784_ (.CLK(clknet_3_6__leaf_clk),
    .D(_035_),
    .RESET_B(net24),
    .Q(\dcnt[4] ));
 sky130_fd_sc_hd__dfrtp_1 _785_ (.CLK(clknet_3_6__leaf_clk),
    .D(_036_),
    .RESET_B(net24),
    .Q(\dcnt[5] ));
 sky130_fd_sc_hd__dfrtp_1 _786_ (.CLK(clknet_3_3__leaf_clk),
    .D(_037_),
    .RESET_B(net24),
    .Q(\dcnt[6] ));
 sky130_fd_sc_hd__dfrtp_1 _787_ (.CLK(clknet_3_3__leaf_clk),
    .D(_038_),
    .RESET_B(net18),
    .Q(\dcnt[7] ));
 sky130_fd_sc_hd__dfrtp_1 _788_ (.CLK(clknet_3_2__leaf_clk),
    .D(_039_),
    .RESET_B(net19),
    .Q(\dcnt[8] ));
 sky130_fd_sc_hd__dfrtp_1 _789_ (.CLK(clknet_3_2__leaf_clk),
    .D(_040_),
    .RESET_B(net18),
    .Q(\dcnt[9] ));
 sky130_fd_sc_hd__dfrtp_2 _790_ (.CLK(clknet_3_3__leaf_clk),
    .D(_041_),
    .RESET_B(net18),
    .Q(\dcnt[10] ));
 sky130_fd_sc_hd__dfrtp_1 _791_ (.CLK(clknet_3_2__leaf_clk),
    .D(_042_),
    .RESET_B(net18),
    .Q(\dcnt[11] ));
 sky130_fd_sc_hd__dfrtp_2 _792_ (.CLK(clknet_3_2__leaf_clk),
    .D(_043_),
    .RESET_B(net19),
    .Q(\dcnt[12] ));
 sky130_fd_sc_hd__dfrtp_1 _793_ (.CLK(clknet_3_2__leaf_clk),
    .D(_044_),
    .RESET_B(net19),
    .Q(\dcnt[13] ));
 sky130_fd_sc_hd__dfrtp_1 _794_ (.CLK(clknet_3_2__leaf_clk),
    .D(_045_),
    .RESET_B(net19),
    .Q(\dcnt[14] ));
 sky130_fd_sc_hd__dfrtp_1 _795_ (.CLK(clknet_3_2__leaf_clk),
    .D(_046_),
    .RESET_B(net19),
    .Q(\dcnt[15] ));
 sky130_fd_sc_hd__dfrtp_1 _796_ (.CLK(clknet_3_2__leaf_clk),
    .D(_047_),
    .RESET_B(net19),
    .Q(\dcnt[16] ));
 sky130_fd_sc_hd__dfrtp_1 _797_ (.CLK(clknet_3_2__leaf_clk),
    .D(_048_),
    .RESET_B(net19),
    .Q(\dcnt[17] ));
 sky130_fd_sc_hd__dfrtp_1 _798_ (.CLK(clknet_3_2__leaf_clk),
    .D(_049_),
    .RESET_B(net18),
    .Q(\dcnt[18] ));
 sky130_fd_sc_hd__dfrtp_1 _799_ (.CLK(clknet_3_2__leaf_clk),
    .D(_050_),
    .RESET_B(net18),
    .Q(\dcnt[19] ));
 sky130_fd_sc_hd__dfrtp_1 _800_ (.CLK(clknet_3_3__leaf_clk),
    .D(_051_),
    .RESET_B(net20),
    .Q(\dcnt[20] ));
 sky130_fd_sc_hd__dfrtp_1 _801_ (.CLK(clknet_3_0__leaf_clk),
    .D(_052_),
    .RESET_B(net15),
    .Q(\px[0] ));
 sky130_fd_sc_hd__dfrtp_1 _802_ (.CLK(clknet_3_0__leaf_clk),
    .D(_053_),
    .RESET_B(net15),
    .Q(\px[1] ));
 sky130_fd_sc_hd__dfrtp_1 _803_ (.CLK(clknet_3_0__leaf_clk),
    .D(_054_),
    .RESET_B(net15),
    .Q(\px[2] ));
 sky130_fd_sc_hd__dfrtp_1 _804_ (.CLK(clknet_3_0__leaf_clk),
    .D(_055_),
    .RESET_B(net15),
    .Q(\px[3] ));
 sky130_fd_sc_hd__dfrtp_1 _805_ (.CLK(clknet_3_0__leaf_clk),
    .D(_056_),
    .RESET_B(net15),
    .Q(\px[4] ));
 sky130_fd_sc_hd__dfrtp_1 _806_ (.CLK(clknet_3_1__leaf_clk),
    .D(_057_),
    .RESET_B(net15),
    .Q(\px[5] ));
 sky130_fd_sc_hd__dfrtp_1 _807_ (.CLK(clknet_3_1__leaf_clk),
    .D(_058_),
    .RESET_B(net16),
    .Q(\px[6] ));
 sky130_fd_sc_hd__dfrtp_1 _808_ (.CLK(clknet_3_1__leaf_clk),
    .D(_059_),
    .RESET_B(net16),
    .Q(\px[7] ));
 sky130_fd_sc_hd__dfrtp_1 _809_ (.CLK(clknet_3_0__leaf_clk),
    .D(_060_),
    .RESET_B(net15),
    .Q(\px[8] ));
 sky130_fd_sc_hd__dfrtp_1 _810_ (.CLK(clknet_3_1__leaf_clk),
    .D(_061_),
    .RESET_B(net17),
    .Q(\px[9] ));
 sky130_fd_sc_hd__dfrtp_1 _811_ (.CLK(clknet_3_0__leaf_clk),
    .D(_062_),
    .RESET_B(net15),
    .Q(\px[10] ));
 sky130_fd_sc_hd__dfrtp_1 _812_ (.CLK(clknet_3_0__leaf_clk),
    .D(_063_),
    .RESET_B(net15),
    .Q(\px[11] ));
 sky130_fd_sc_hd__dfrtp_1 _813_ (.CLK(clknet_3_0__leaf_clk),
    .D(_064_),
    .RESET_B(net16),
    .Q(\px[12] ));
 sky130_fd_sc_hd__dfrtp_1 _814_ (.CLK(clknet_3_0__leaf_clk),
    .D(_065_),
    .RESET_B(net16),
    .Q(\px[13] ));
 sky130_fd_sc_hd__dfrtp_1 _815_ (.CLK(clknet_3_1__leaf_clk),
    .D(_066_),
    .RESET_B(net16),
    .Q(\px[14] ));
 sky130_fd_sc_hd__dfrtp_1 _816_ (.CLK(clknet_3_0__leaf_clk),
    .D(_067_),
    .RESET_B(net19),
    .Q(\px[15] ));
 sky130_fd_sc_hd__dfrtp_1 _817_ (.CLK(clknet_3_0__leaf_clk),
    .D(net58),
    .RESET_B(net16),
    .Q(\px[16] ));
 sky130_fd_sc_hd__dfrtp_1 _818_ (.CLK(clknet_3_1__leaf_clk),
    .D(_069_),
    .RESET_B(net17),
    .Q(pxhi));
 sky130_fd_sc_hd__dfrtp_2 _819_ (.CLK(clknet_3_1__leaf_clk),
    .D(_070_),
    .RESET_B(net17),
    .Q(sending));
 sky130_fd_sc_hd__dfrtp_1 _820_ (.CLK(clknet_3_4__leaf_clk),
    .D(_071_),
    .RESET_B(net23),
    .Q(\pcolor_l[1] ));
 sky130_fd_sc_hd__dfrtp_1 _821_ (.CLK(clknet_3_4__leaf_clk),
    .D(_072_),
    .RESET_B(net23),
    .Q(\pcolor_l[2] ));
 sky130_fd_sc_hd__dfrtp_1 _822_ (.CLK(clknet_3_4__leaf_clk),
    .D(_073_),
    .RESET_B(net23),
    .Q(\pcolor_l[3] ));
 sky130_fd_sc_hd__dfrtp_1 _823_ (.CLK(clknet_3_1__leaf_clk),
    .D(_074_),
    .RESET_B(net23),
    .Q(\pcolor_l[4] ));
 sky130_fd_sc_hd__dfrtp_1 _824_ (.CLK(clknet_3_1__leaf_clk),
    .D(_075_),
    .RESET_B(net17),
    .Q(\pcolor_l[5] ));
 sky130_fd_sc_hd__dfrtp_1 _825_ (.CLK(clknet_3_4__leaf_clk),
    .D(_076_),
    .RESET_B(net23),
    .Q(\pcolor_l[0] ));
 sky130_fd_sc_hd__dfrtp_1 _826_ (.CLK(clknet_3_7__leaf_clk),
    .D(_077_),
    .RESET_B(net22),
    .Q(net14));
 sky130_fd_sc_hd__dfrtp_1 _827_ (.CLK(clknet_3_6__leaf_clk),
    .D(_078_),
    .RESET_B(net25),
    .Q(net13));
 sky130_fd_sc_hd__dfstp_1 _828_ (.CLK(clknet_3_1__leaf_clk),
    .D(_079_),
    .SET_B(net17),
    .Q(net11));
 sky130_fd_sc_hd__dfrtp_4 _829_ (.CLK(clknet_3_7__leaf_clk),
    .D(net26),
    .RESET_B(net25),
    .Q(spi_done));
 sky130_fd_sc_hd__dfstp_1 _830_ (.CLK(clknet_3_2__leaf_clk),
    .D(_080_),
    .SET_B(net19),
    .Q(net12));
 sky130_fd_sc_hd__dfrtp_2 _831_ (.CLK(clknet_3_7__leaf_clk),
    .D(_081_),
    .RESET_B(net25),
    .Q(\sbit[0] ));
 sky130_fd_sc_hd__dfrtp_1 _832_ (.CLK(clknet_3_7__leaf_clk),
    .D(_082_),
    .RESET_B(net25),
    .Q(\sbit[1] ));
 sky130_fd_sc_hd__dfrtp_1 _833_ (.CLK(clknet_3_7__leaf_clk),
    .D(_083_),
    .RESET_B(net25),
    .Q(\sbit[2] ));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_0_clk (.A(clk),
    .X(clknet_0_clk));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_3_0__f_clk (.A(clknet_0_clk),
    .X(clknet_3_0__leaf_clk));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_3_1__f_clk (.A(clknet_0_clk),
    .X(clknet_3_1__leaf_clk));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_3_2__f_clk (.A(clknet_0_clk),
    .X(clknet_3_2__leaf_clk));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_3_3__f_clk (.A(clknet_0_clk),
    .X(clknet_3_3__leaf_clk));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_3_4__f_clk (.A(clknet_0_clk),
    .X(clknet_3_4__leaf_clk));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_3_5__f_clk (.A(clknet_0_clk),
    .X(clknet_3_5__leaf_clk));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_3_6__f_clk (.A(clknet_0_clk),
    .X(clknet_3_6__leaf_clk));
 sky130_fd_sc_hd__clkbuf_16 clkbuf_3_7__f_clk (.A(clknet_0_clk),
    .X(clknet_3_7__leaf_clk));
 sky130_fd_sc_hd__clkbuf_4 fanout15 (.A(net16),
    .X(net15));
 sky130_fd_sc_hd__clkbuf_4 fanout16 (.A(net20),
    .X(net16));
 sky130_fd_sc_hd__clkbuf_2 fanout17 (.A(net20),
    .X(net17));
 sky130_fd_sc_hd__clkbuf_4 fanout18 (.A(net20),
    .X(net18));
 sky130_fd_sc_hd__clkbuf_4 fanout19 (.A(net20),
    .X(net19));
 sky130_fd_sc_hd__clkbuf_2 fanout20 (.A(net7),
    .X(net20));
 sky130_fd_sc_hd__clkbuf_4 fanout21 (.A(net23),
    .X(net21));
 sky130_fd_sc_hd__clkbuf_4 fanout22 (.A(net23),
    .X(net22));
 sky130_fd_sc_hd__buf_2 fanout23 (.A(net7),
    .X(net23));
 sky130_fd_sc_hd__clkbuf_4 fanout24 (.A(net7),
    .X(net24));
 sky130_fd_sc_hd__clkbuf_4 fanout25 (.A(net7),
    .X(net25));
 sky130_fd_sc_hd__dlygate4sd3_1 hold1 (.A(\sst[3] ),
    .X(net26));
 sky130_fd_sc_hd__dlygate4sd3_1 hold10 (.A(\dcnt[2] ),
    .X(net35));
 sky130_fd_sc_hd__dlygate4sd3_1 hold11 (.A(\dcnt[4] ),
    .X(net36));
 sky130_fd_sc_hd__dlygate4sd3_1 hold12 (.A(\dmode[0] ),
    .X(net37));
 sky130_fd_sc_hd__dlygate4sd3_1 hold13 (.A(\dcnt[18] ),
    .X(net38));
 sky130_fd_sc_hd__dlygate4sd3_1 hold14 (.A(\px[7] ),
    .X(net39));
 sky130_fd_sc_hd__dlygate4sd3_1 hold15 (.A(\px[8] ),
    .X(net40));
 sky130_fd_sc_hd__dlygate4sd3_1 hold16 (.A(\px[11] ),
    .X(net41));
 sky130_fd_sc_hd__dlygate4sd3_1 hold17 (.A(\dcnt[16] ),
    .X(net42));
 sky130_fd_sc_hd__dlygate4sd3_1 hold18 (.A(\dcnt[11] ),
    .X(net43));
 sky130_fd_sc_hd__dlygate4sd3_1 hold19 (.A(\dcnt[7] ),
    .X(net44));
 sky130_fd_sc_hd__dlygate4sd3_1 hold2 (.A(\sst[2] ),
    .X(net27));
 sky130_fd_sc_hd__dlygate4sd3_1 hold20 (.A(\dcnt[1] ),
    .X(net45));
 sky130_fd_sc_hd__dlygate4sd3_1 hold21 (.A(_256_),
    .X(net46));
 sky130_fd_sc_hd__dlygate4sd3_1 hold22 (.A(\px[14] ),
    .X(net47));
 sky130_fd_sc_hd__dlygate4sd3_1 hold23 (.A(\px[2] ),
    .X(net48));
 sky130_fd_sc_hd__dlygate4sd3_1 hold24 (.A(\dcnt[17] ),
    .X(net49));
 sky130_fd_sc_hd__dlygate4sd3_1 hold25 (.A(\dcnt[15] ),
    .X(net50));
 sky130_fd_sc_hd__dlygate4sd3_1 hold26 (.A(\px[4] ),
    .X(net51));
 sky130_fd_sc_hd__dlygate4sd3_1 hold27 (.A(\sbit[2] ),
    .X(net52));
 sky130_fd_sc_hd__dlygate4sd3_1 hold28 (.A(\px[13] ),
    .X(net53));
 sky130_fd_sc_hd__dlygate4sd3_1 hold29 (.A(\dcnt[12] ),
    .X(net54));
 sky130_fd_sc_hd__dlygate4sd3_1 hold3 (.A(net14),
    .X(net28));
 sky130_fd_sc_hd__dlygate4sd3_1 hold30 (.A(\dcnt[6] ),
    .X(net55));
 sky130_fd_sc_hd__dlygate4sd3_1 hold31 (.A(\dcnt[13] ),
    .X(net56));
 sky130_fd_sc_hd__dlygate4sd3_1 hold32 (.A(\px[16] ),
    .X(net57));
 sky130_fd_sc_hd__dlygate4sd3_1 hold33 (.A(_068_),
    .X(net58));
 sky130_fd_sc_hd__dlygate4sd3_1 hold34 (.A(\px[6] ),
    .X(net59));
 sky130_fd_sc_hd__dlygate4sd3_1 hold35 (.A(\sbuf[6] ),
    .X(net60));
 sky130_fd_sc_hd__dlygate4sd3_1 hold36 (.A(spi_start),
    .X(net61));
 sky130_fd_sc_hd__dlygate4sd3_1 hold37 (.A(_008_),
    .X(net62));
 sky130_fd_sc_hd__dlygate4sd3_1 hold38 (.A(\sbuf[2] ),
    .X(net63));
 sky130_fd_sc_hd__dlygate4sd3_1 hold39 (.A(\dcnt[8] ),
    .X(net64));
 sky130_fd_sc_hd__dlygate4sd3_1 hold4 (.A(\pcolor_l[1] ),
    .X(net29));
 sky130_fd_sc_hd__dlygate4sd3_1 hold40 (.A(\sbuf[5] ),
    .X(net65));
 sky130_fd_sc_hd__dlygate4sd3_1 hold41 (.A(\dcnt[10] ),
    .X(net66));
 sky130_fd_sc_hd__dlygate4sd3_1 hold42 (.A(\pcolor_l[4] ),
    .X(net67));
 sky130_fd_sc_hd__dlygate4sd3_1 hold43 (.A(\spi_byte[7] ),
    .X(net68));
 sky130_fd_sc_hd__dlygate4sd3_1 hold44 (.A(\sbuf[1] ),
    .X(net69));
 sky130_fd_sc_hd__dlygate4sd3_1 hold45 (.A(\spi_byte[1] ),
    .X(net70));
 sky130_fd_sc_hd__dlygate4sd3_1 hold46 (.A(\pcolor_l[2] ),
    .X(net71));
 sky130_fd_sc_hd__dlygate4sd3_1 hold47 (.A(\sbuf[7] ),
    .X(net72));
 sky130_fd_sc_hd__dlygate4sd3_1 hold48 (.A(\sbuf[3] ),
    .X(net73));
 sky130_fd_sc_hd__dlygate4sd3_1 hold49 (.A(\pcolor_l[3] ),
    .X(net74));
 sky130_fd_sc_hd__dlygate4sd3_1 hold5 (.A(\spi_byte[0] ),
    .X(net30));
 sky130_fd_sc_hd__dlygate4sd3_1 hold50 (.A(\sbuf[4] ),
    .X(net75));
 sky130_fd_sc_hd__dlygate4sd3_1 hold51 (.A(\pcolor_l[5] ),
    .X(net76));
 sky130_fd_sc_hd__dlygate4sd3_1 hold52 (.A(\spi_byte[2] ),
    .X(net77));
 sky130_fd_sc_hd__dlygate4sd3_1 hold53 (.A(\spi_byte[6] ),
    .X(net78));
 sky130_fd_sc_hd__dlygate4sd3_1 hold54 (.A(\sbit[1] ),
    .X(net79));
 sky130_fd_sc_hd__dlygate4sd3_1 hold55 (.A(net11),
    .X(net80));
 sky130_fd_sc_hd__dlygate4sd3_1 hold56 (.A(\spi_byte[3] ),
    .X(net81));
 sky130_fd_sc_hd__dlygate4sd3_1 hold57 (.A(\spi_byte[4] ),
    .X(net82));
 sky130_fd_sc_hd__dlygate4sd3_1 hold58 (.A(\dcnt[20] ),
    .X(net83));
 sky130_fd_sc_hd__dlygate4sd3_1 hold6 (.A(_009_),
    .X(net31));
 sky130_fd_sc_hd__dlygate4sd3_1 hold7 (.A(\dcnt[3] ),
    .X(net32));
 sky130_fd_sc_hd__dlygate4sd3_1 hold8 (.A(\dcnt[9] ),
    .X(net33));
 sky130_fd_sc_hd__dlygate4sd3_1 hold9 (.A(\dcnt[14] ),
    .X(net34));
 sky130_fd_sc_hd__clkbuf_1 input1 (.A(pix_gray[2]),
    .X(net1));
 sky130_fd_sc_hd__dlymetal6s2s_1 input2 (.A(pix_gray[3]),
    .X(net2));
 sky130_fd_sc_hd__clkbuf_1 input3 (.A(pix_gray[4]),
    .X(net3));
 sky130_fd_sc_hd__buf_1 input4 (.A(pix_gray[5]),
    .X(net4));
 sky130_fd_sc_hd__buf_1 input5 (.A(pix_gray[6]),
    .X(net5));
 sky130_fd_sc_hd__buf_1 input6 (.A(pix_gray[7]),
    .X(net6));
 sky130_fd_sc_hd__clkbuf_2 input7 (.A(rst_n),
    .X(net7));
 sky130_fd_sc_hd__clkbuf_4 output10 (.A(net10),
    .X(pix_next));
 sky130_fd_sc_hd__clkbuf_4 output11 (.A(net11),
    .X(tft_cs));
 sky130_fd_sc_hd__clkbuf_4 output12 (.A(net12),
    .X(tft_dc));
 sky130_fd_sc_hd__clkbuf_4 output13 (.A(net13),
    .X(tft_mosi));
 sky130_fd_sc_hd__buf_2 output14 (.A(net14),
    .X(tft_sck));
 sky130_fd_sc_hd__clkbuf_4 output8 (.A(net8),
    .X(frame_start));
 sky130_fd_sc_hd__clkbuf_4 output9 (.A(net9),
    .X(init_done));
endmodule

