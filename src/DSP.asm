/*	

	Acest program initializeaza placa de dezvoltare EZ_LITE 2181
	 - procesorul ADSP2181 ( mod de lucru)
	 - codecul AD1847
	- testeaza extensia IO pentru EZ-KIT_LITE
	- porul de intrare ( citire SW) - la adresa 0x1FF
	- portul de iesire ( afisare ) - la adresa 0xFF
	- citeste portul PF (PF3-PF0)
	- activeaza intreruperea IRQE - pentru a multiplexa afisarea pe PORT_DISP
*/


#include    "def2181.h"    


#define PORT_OUT 0xFF
#define PORT_IN 0x1FF

;//

#define   N         205
#define   tones     8
#define   tones_x_2 16
#define   scale -8

#define F0 770
#define F1 1477

#define MIN_LEVEL 0x100

;//
#define M 2050
#define N4 820
;// 
;//
#define MAX 0x7FFF
#define MIN 0x8000
;//
/*
Frecventele sint: 697,770,852,941,1209,1336,1477,1633 
in aceasta ordine a bitilor in variabila outcode: 0,1,2,3,4,5,6,7
*/

.SECTION/DM		buf_var1;
.var    rx_buf[4];      /* Status + L data + R data + switch */
.var switch;

.SECTION/DM		buf_var2;
.var    	tx_buf[3] = 0xc000, 0x0000, 0x0000;      /* Cmd + L data + R data    */

.SECTION/DM		buf_var3;
.var    init_cmds[13] = 0xc002,     /*
                        				Left input control reg
                        				b7-6: 0=left line 1
                              			1=left aux 1
                              			2=left line 2
                              			3=left line 1 post-mixed loopback
                        			b5-4: res
                        			b3-0: left input gain x 1.5 dB
                    				*/
        				0xc102,     /*
                        				Right input control reg
                        				b7-6: 0=right line 1
                              				1=right aux 1
                              				2=right line 2
                              				3=right line 1 post-mixed loopback
                        				b5-4: res
                        				b3-0: right input gain x 1.5 dB
                    				*/
        				0xc288,     /*
                        				left aux 1 control reg
                        				b7  : 1=left aux 1 mute
                        				b6-5: res
                        				b4-0: gain/atten x 1.5, 08= 0dB, 00= 12dB
                    				*/
        				0xc388,     /*
                        				right aux 1 control reg
                        				b7  : 1=right aux 1 mute
                        				b6-5: res
                        				b4-0: gain/atten x 1.5, 08= 0dB, 00= 12dB
                    				*/
        				0xc488,     /*
                        				left aux 2 control reg
                        				b7  : 1=left aux 2 mute
                        				b6-5: res
                        				b4-0: gain/atten x 1.5, 08= 0dB, 00= 12dB
                    				*/
        				0xc588,     /*
                        				right aux 2 control reg
                        				b7  : 1=right aux 2 mute
                        				b6-5: res
                        				b4-0: gain/atten x 1.5, 08= 0dB, 00= 12dB
                    				*/
        				0xc680,     /*
                        				left DAC control reg
                        				b7  : 1=left DAC mute
                        				b6  : res
                        				b5-0: attenuation x 1.5 dB
                    				*/
        				0xc780,     /*
                        				right DAC control reg
                        				b7  : 1=right DAC mute
                        				b6  : res
                        				b5-0: attenuation x 1.5 dB
                    				*/
        				0xc850,     /*
                        				data format register
                        				b7  : res
                        				b5-6: 0=8-bit unsigned linear PCM
                              				1=8-bit u-law companded
                              				2=16-bit signed linear PCM
                              				3=8-bit A-law companded
                        				b4  : 0=mono, 1=stereo
                        				b0-3: 0=  8.
                              				1=  5.5125
                              				2= 16.
                              				3= 11.025
                              				4= 27.42857
                              				5= 18.9
                              				6= 32.
                              				7= 22.05
                              				8=   .
                              				9= 37.8
                              				a=   .
                              				b= 44.1
                              				c= 48.
                              				d= 33.075
                              				e=  9.6
                              				f=  6.615
                       				(b0) : 0=XTAL1 24.576 MHz; 1=XTAL2 16.9344 MHz
                    				*/
        				0xc909,     /*
                        				interface configuration reg
                        				b7-4: res
                        				b3  : 1=autocalibrate
                        				b2-1: res
                        				b0  : 1=playback enabled
                    				*/
        				0xca00,     /*
                        				pin control reg
                        				b7  : logic state of pin XCTL1
                       					b6  : logic state of pin XCTL0
                        				b5  : master - 1=tri-state CLKOUT
                              				slave  - x=tri-state CLKOUT
                        				b4-0: res
                    				*/
        				0xcc40,     /*
	THIS PROGRAM USES 16 SLOTS PER FRAME
                        				miscellaneous information reg
                        				b7  : 1=16 slots per frame, 0=32 slots per frame
                        				b6  : 1=2-wire system, 0=1-wire system
                        				b5-0: res
                    				*/
        				0xcd00;     /*
                        				digital mix control reg
                        				b7-2: attenuation x 1.5 dB
                        				b1  : res
                        				b0  : 1=digital mix enabled
                    				*/

.SECTION/DM		data1;
.var        stat_flag;
;//
.var TAB_DISP[16] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71};
;// 0,1,2,3,4,5,6,7,8,9,A,b,C,d,E,F
.var flag_disp;

;//
.var/circ Q1Q2_buff[tones_x_2];    ;//{ Goertzel feedback loop storage elements }


;//Frecventele sunt: 697, 	770,  852, 941 
.var frecvente0[4] ={0x2B9, 0x302, 0x354, 0x3ad};
;//Frecventele sint:1209,1336,1477,1633 
.var frecvente1[4] ={0x1209, 0x556, 0x5c5, 0x661};

.var      outcode;					;// codul de iesire
.var in_sample;               ;//{ esantionul de intrare curent }
.var      countN;                  ;//{ numara esantioanele 1, 2, 3, ..., N  }
;//{ min "tone-present" mnsqr level }
.var      min_tone_level[tones]=MIN_LEVEL,MIN_LEVEL,MIN_LEVEL,MIN_LEVEL,MIN_LEVEL,MIN_LEVEL,MIN_LEVEL,MIN_LEVEL;
;//{ valorile rezultate 1.15 mnsqr Goertzel  }
.var mnsqr[tones];            
.var bits[tones]=0x0001,0x0002,0x0004,0x0008,0x0010,0x0020,0x0040,0x0080;
;//
.var sin_coeff[5]={0x3240,0x0053, 0xAACC, 0x08B7, 0x1CCE};
;//
.var     sum0;
.var	 hertz0;
.var     sum1;
.var	 hertz1;

;// doar test
.var cg;
.var outcd_f0_test;
.var outcd_f1_test;
;//
.var in; 	;// intrarea (o citire pe intrerupere)
.var Q; 	;// variabila de stare PS
.var cnt1;	;// contor 0x7FFF
.var cnt2;	;// contor 0x8000
.var cnt3;	;// contor generator
.var cnt4;	;// contor perioada asteptare raspuns
.var REC_Rdy;	;// receptor gata
.var CNTRec;	;// contor perioade rec.
.var CNTGen;	;// contor perioade gen.
.var CODR;	;// cod rec.
.var CODG;	;// cod gen.
.var fc;	;// frecventa de generat 1 sau 0
;//
.SECTION/PM		pm_da;
;//{ 2.14 coeficientii Goertzel : 2*cos(2*PI*k/N) }
.var/circ coefs[tones]=0x6d02,0x68b2,0x63fd,0x5eef,0x4a71, 0x4091, 0x3291, 0x23ce;

/*** Interrupt Vector Table ***/
.SECTION/PM     interrupts;
		jump start;  rti; rti; rti;     /*00: reset */
        ;//rti;         rti; rti; rti;     /*04: IRQ2 */
        
        jump input_samples; rti; rti; rti;
        
        rti;         rti; rti; rti;     /*08: IRQL1 */
        rti;         rti; rti; rti;     /*0c: IRQL0 */
        ar = dm(stat_flag);             /*10: SPORT0 tx */
        ar = pass ar;
        if eq rti;
        jump next_cmd;
        jump input_samples;             /*14: SPORT1 rx */
                     rti; rti; rti;
        jump IRQE_SCI;         rti; rti; rti;     /*18: IRQE */
        rti;         rti; rti; rti;     /*1c: BDMA */
        rti;         rti; rti; rti;     /*20: SPORT1 tx or IRQ1 */
        rti;         rti; rti; rti;     /*24: SPORT1 rx or IRQ0 */
        nop;         rti; rti; rti;     /*28: timer */
        rti;         rti; rti; rti;     /*2c: power down */


.SECTION/PM		seg_code;
/*******************************************************************************
 *
 *  ADSP 2181 intialization
 *
 *******************************************************************************/
start:
        /*   shut down sport 0 */
        ax0 = b#0000100000000000;   
		dm (Sys_Ctrl_Reg) = ax0;
		ena timer;

		i5 = switch;
        i5 = rx_buf;
        l5 = LENGTH(rx_buf);
        i6 = tx_buf;
        l6 = LENGTH(tx_buf);
        i3 = init_cmds;
        l3 = LENGTH(init_cmds);

        m1 = 1;
        m5 = 1;


/*================== S E R I A L   P O R T   #0   S T U F F ==================*/
        ax0 = b#0000110011010111;   dm (Sport0_Autobuf_Ctrl) = ax0;
            /*  |||!|-/!/|-/|/|+- receive autobuffering 0=off, 1=on
                |||!|  ! |  | +-- transmit autobuffering 0=off, 1=on
                |||!|  ! |  +---- | receive m?
                |||!|  ! |        | m5
                |||!|  ! +------- ! receive i?
                |||!|  !          ! i5
                |||!|  !          !
                |||!|  +========= | transmit m?
                |||!|             | m5
                |||!+------------ ! transmit i?
                |||!              ! i6
                |||!              !
                |||+============= | BIASRND MAC biased rounding control bit
                ||+-------------- 0
                |+--------------- | CLKODIS CLKOUT disable control bit
                +---------------- 0
            */

        ax0 = 0;    dm (Sport0_Rfsdiv) = ax0;
            /*   RFSDIV = SCLK Hz/RFS Hz - 1 */
        ax0 = 0;    dm (Sport0_Sclkdiv) = ax0;
            /*   SCLK = CLKOUT / (2  (SCLKDIV + 1) */
        ax0 = b#1000011000001111;   dm (Sport0_Ctrl_Reg) = ax0;
            /*  multichannel
                ||+--/|!||+/+---/ | number of bit per word - 1
                |||   |!|||       | = 15
                |||   |!|||       |
                |||   |!|||       |
                |||   |!||+====== ! 0=right just, 0-fill; 1=right just, signed
                |||   |!||        ! 2=compand u-law; 3=compand A-law
                |||   |!|+------- receive framing logic 0=pos, 1=neg
                |||   |!+-------- transmit data valid logic 0=pos, 1=neg
                |||   |+========= RFS 0=ext, 1=int
                |||   +---------- multichannel length 0=24, 1=32 words
                ||+-------------- | frame sync to occur this number of clock
                ||                | cycle before first bit
                ||                |
                ||                |
                |+--------------- ISCLK 0=ext, 1=int
                +---------------- multichannel 0=disable, 1=enable
            */
            /*  non-multichannel
                |||!|||!|||!+---/ | number of bit per word - 1
                |||!|||!|||!      | = 15
                |||!|||!|||!      |
                |||!|||!|||!      |
                |||!|||!|||+===== ! 0=right just, 0-fill; 1=right just, signed
                |||!|||!||+------ ! 2=compand u-law; 3=compand A-law
                |||!|||!|+------- receive framing logic 0=pos, 1=neg
                |||!|||!+-------- transmit framing logic 0=pos, 1=neg
                |||!|||+========= RFS 0=ext, 1=int
                |||!||+---------- TFS 0=ext, 1=int
                |||!|+----------- TFS width 0=FS before data, 1=FS in sync
                |||!+------------ TFS 0=no, 1=required
                |||+============= RFS width 0=FS before data, 1=FS in sync
                ||+-------------- RFS 0=no, 1=required
                |+--------------- ISCLK 0=ext, 1=int
                +---------------- multichannel 0=disable, 1=enable
            */


        ax0 = b#0000000000000111;   dm (Sport0_Tx_Words0) = ax0;
            /*  ^15          00^   transmit word enables: channel # == bit # */
        ax0 = b#0000000000000111;   dm (Sport0_Tx_Words1) = ax0;
            /*  ^31          16^   transmit word enables: channel # == bit # */
        ax0 = b#0000000000000111;   dm (Sport0_Rx_Words0) = ax0;
            /*  ^15          00^   receive word enables: channel # == bit # */
        ax0 = b#0000000000000111;   dm (Sport0_Rx_Words1) = ax0;
            /*  ^31          16^   receive word enables: channel # == bit # */


/*============== S Y S T E M   A N D   M E M O R Y   S T U F F ==============*/
        ax0 = b#0001100000000000;   dm (Sys_Ctrl_Reg) = ax0;
            /*  +-/!||+-----/+-/- | program memory wait states
                |  !|||           | 0
                |  !|||           |
                |  !||+---------- 0
                |  !||            0
                |  !||            0
                |  !||            0
                |  !||            0
                |  !||            0
                |  !||            0
                |  !|+----------- SPORT1 1=serial port, 0=FI, FO, IRQ0, IRQ1,..
                |  !+------------ SPORT1 1=enabled, 0=disabled
                |  +============= SPORT0 1=enabled, 0=disabled
                +---------------- 0
                                  0
                                  0
            */



        ifc = b#00000011111110;         /* clear pending interrupt */
        nop;


        icntl = b#00010;
            /*    ||||+- | IRQ0: 0=level, 1=edge
                  |||+-- | IRQ1: 0=level, 1=edge
                  ||+--- | IRQ2: 0=level, 1=edge
                  |+---- 0
                  |----- | IRQ nesting: 0=disabled, 1=enabled
            */


        mstat = b#1100000;
            /*    ||||||+- | Data register bank select
                  |||||+-- | FFT bit reverse mode (DAG1)
                  ||||+--- | ALU overflow latch mode, 1=sticky
                  |||+---- | AR saturation mode, 1=saturate, 0=wrap
                  ||+----- | MAC result, 0=fractional, 1=integer
                  |+------ | timer enable
                  +------- | GO MODE
            */



;//
jump skip;

;//
/*******************************************************************************
 *
 *  ADSP 1847 Codec intialization
 *
 *******************************************************************************/

        /*   clear flag */
        ax0 = 1;
        dm(stat_flag) = ax0;

        /*   enable transmit interrupt */
        ena ints;
        imask = b#0001000001;
            /*    |||||||||+ | timer
                  ||||||||+- | SPORT1 rec or IRQ0
                  |||||||+-- | SPORT1 trx or IRQ1
                  ||||||+--- | BDMA
                  |||||+---- | IRQE
                  ||||+----- | SPORT0 rec
                  |||+------ | SPORT0 trx
                  ||+------- | IRQL0
                  |+-------- | IRQL1
                  +--------- | IRQ2
            */


        ax0 = dm (i6, m5);          /* start interrupt */
        tx0 = ax0;

check_init:
        ax0 = dm (stat_flag);       /* wait for entire init */
        af = pass ax0;              /* buffer to be sent to */
        if ne jump check_init;      /* the codec            */

        ay0 = 2;
check_aci1:
        ax0 = dm (rx_buf);          /* once initialized, wait for codec */
        ar = ax0 and ay0;           /* to come out of autocalibration */
        if eq jump check_aci1;      /* wait for bit set */

check_aci2:
        ax0 = dm (rx_buf);          /* wait for bit clear */
        ar = ax0 and ay0;
        if ne jump check_aci2;
        idle;

        ay0 = 0xbf3f;               /* unmute left DAC */
        ax0 = dm (init_cmds + 6);
        ar = ax0 AND ay0;
        dm (tx_buf) = ar;
        idle;

        ax0 = dm (init_cmds + 7);   /* unmute right DAC */
        ar = ax0 AND ay0;
        dm (tx_buf) = ar;
        idle;


        ifc = b#00000011111110;     /* clear any pending interrupt */
        nop;

      ;//imask = b#0001100001; /* enable rx0 interrupt*/
        
		imask = b#0001110001;       /* enable rx0 interrupt and IRQE */
            /*    |||||||||+ | timer
                  ||||||||+- | SPORT1 rec or IRQ0
                  |||||||+-- | SPORT1 trx or IRQ1
                  ||||||+--- | BDMA
                  |||||+---- | IRQE
                  ||||+----- | SPORT0 rec
                  |||+------ | SPORT0 trx
                  ||+------- | IRQL0
                  |+-------- | IRQL1
                  +--------- | IRQ2
            */
         

/*   end codec initialization, begin filter demo initialization */

skip: imask=0x200;

;// wait states

si=0xFFFF;
dm(Dm_Wait_Reg)=si;

si=0x00f0;
dm(Prog_Flag_Comp_Sel_Ctrl)=si; ;// PF0-3 inputs , PF4-7 outputs 

dm(flag_disp)=si;				;// clear flag_disp


;//
call init_generator;
call init_receptor;
call set_encrypt;
call set_durata;
;//
/* wait for char to go out */
wt:

	nop;
		jump wt;
		
		
/*------------------------------------------------------------------------------
-
- SPORT0 interrupt handler
-
------------------------------------------------------------------------------*/

input_samples:
	ena sec_reg; /* use shadow register bank */
	
	call my_app;
	
	;// display
	ax0=dm(flag_disp);
	ay0=0;
	ar=ax0-ay0;	
	if ne jump disp_PF;
	si=IO(PORT_IN);
	IO(PORT_OUT)=si;
	rti;
	
	
disp_PF:
	ax0=dm(Prog_Flag_Data);
	ay0=0x000F;
	ar=ax0 and ay0;
	call afis_PF;
	rti;
	
	
	
/*------------------------------------------------------------------------------
-
- transmit interrupt used for Codec initialization
-
------------------------------------------------------------------------------*/

next_cmd:
	ena sec_reg;
	ax0 = dm (i3, m1); /* fetch next control word and */
	dm (tx_buf) = ax0; /* place in transmit slot 0 */
	ax0 = i3;
	ay0 = init_cmds;
	ar = ax0 - ay0;
	if gt rti; /* rti if more control words still waiting */
	ax0 = 0xaf00; /* else set done flag and */
	dm (tx_buf) = ax0; /* remove MCE if done initialization */
	ax0 = 0;
	dm (stat_flag) = ax0; /* reset status flag */
	rti;
	
	
afis_PF:
	i1=TAB_DISP;
	m3=ar;
	modify(i1,m3);
	si=dm(i1,m0);
	IO(PORT_OUT)=si;
	rts;

	
IRQE_SCI:
	ax0=dm(flag_disp);
	ay0=0x0001;
	ar=ax0 + ay0;
	ar= ar and ay0;
	dm(flag_disp)=ar;
	toggle fl1;
	rti;
	
	
/*
********************************************
*/


my_app:
	;// for test -  global counter de int.
	ar=dm(cg);
	ar=ar+1;
	dm(cg)=ar;
	
	;// for test -  global counter de int.
	ax1=dm(rx_buf+2);
	dm(in)=ax1; ;// intrarea curenta
	;//
	ax0=dm(Q); ;// starea curenta
	
	ay0=0;
	ar=ax0-ay0;
	if eq jump Q0;
	ay0=1;
	ar=ax0-ay0;
	if eq jump Q1;
	ay0=2;
	ar=ax0-ay0;
	if eq jump Q2;
	ay0=3;
	ar=ax0-ay0;
	if eq jump Q3;
	ay0=4;
	ar=ax0-ay0;
	if eq jump Q4;
	ay0=32;
	ar=ax0-ay0;
	if eq jump Q32;
	ay0=31;
	ar=ax0-ay0;
	if eq jump Q31;
	rts;
	
	
Q0:
	;// se citesc 820 esantioane de 0x7FFF
	;// si un esantion de 0x8000
	ax1=dm(in);
	ay1=MAX;
	ar=ax1-ay1;
	if eq jump inc_cnt1;
	ax1=dm(cnt1);
	ay1=dm(Ndurata1);
	ar=ax1-ay1;
	if ge jump durata1_OK;
	ar=0;
	dm(cnt1)=ar;
	rts;
	durata1_OK:
	ar=0;
	dm(cnt1)=ar;
	ar=1;
	dm(Q)=ar;
	rts;
	inc_cnt1:
	ar=dm(cnt1);
	ar=ar+1;
	dm(cnt1)=ar;
	rts;
	
	
Q1:
;// se citesc 204 esantioane de 0x8000
;// si un esantion de sin
	ax1=dm(in);
	ay1=MIN;
	ar=ax1-ay1;
	if eq jump inc_cnt2;
	ax1=dm(cnt2);
	ay1=dm(Ndurata2); ;// un esantion 0x8000 s-a citit in starea Q=0
	ar=ax1-ay1;
	if ge jump durata2_OK;
	ar=0;
	dm(cnt2)=ar;
	dm(Q)=ar;
	rts;
	durata2_OK:
	ar=0;
	dm(cnt2)=ar;
	dm(CODR)=ar;
	ar=2;
	dm(Q)=ar;
	rts;
	inc_cnt2:
	ar=dm(cnt2);
	ar=ar+1;
	dm(cnt2)=ar;
	rts;
	
Q2:
	;// receptor
	;// primul esantion s-a citit in Q=1 (se va pierde, nu conteaza)
	;// se vor citi 4 x 205 esantioane
	call receptor;
	ar=dm(REC_Rdy);
	ar= ar-1;
	if ne rts;
	;// REC_Rdy ->0
	ar=0;
	dm(REC_Rdy)=ar;
	;// CODR = 0000 f1 f2 f3 f4 - OK
	;// CODR = 1111 0000 - eroare rec.
	;// f1 - pe pozitia 6, f0 - pozitia 1
	ax0=dm(outcode);
	test_f1:
	ay0=dm(outcd_f1_test); ;// f1?
	ar=ax0-ay0;
	if ne jump test_f0;
	ay0=0x01;
	ar=dm(CODR);
	ar = ar OR ay0;
	dm(CODR)=ar;
	jump act_CNTRec;
	test_f0:
	ay0=dm(outcd_f0_test); ;// f0?
	ar=ax0-ay0;
	if ne jump err_rec;
	jump act_CNTRec;
	err_rec:
	ar=0xF0;
	dm(CODR)=ar;
	;;// actualizare CNTRec
	act_CNTRec:
	ar=dm(CNTRec);
	ar=ar+1;
	dm(CNTRec)=ar;
	ay0=4;
	ar=ar-ay0;
	if ne jump cont_rec;
	ar=0;
	dm(CNTRec)=ar;
	dm(CNTGen)=ar;
	dm(cnt3)=ar;
	dm(cnt4)=ar;
	;// scrie comanda in PF outputs 4-7
	ar=dm(CODR);
	sr=lshift ar by 4 (hi);
	ax0=sr1;
	dm(Prog_Flag_Data)=ax0;
	ar=3;
	dm(Q)=ar;
	rts;
	cont_rec:
	ar=dm(CODR);
	sr = lshift ar by 1 (hi);
	dm(CODR)=sr1;
	rts;
	
	
Q3:
	;;//asteapa sa vina RDY DUPA CE VINE RDY TRIMI ACK SI CITESTE DATA
	ax0=dm(Prog_Flag_Data); ;// CITESTE DUPA RDY
	ay0=0x000F;
	ar=ax0 and ay0;
	ax0=ar;
	ay0= RDY;
	ar=ax0-ay0;
	if ne rts;
	;//daca trece aici inseamna ca a venit RDY;
	ax0=ACK;
	dm(Prog_Flag_Data)=ax0;
	ar=32;
	dm(Q)=ar;
	rts;
	
	
Q32:
	;// citeste PF inputs 0-3 si scrie CODG
	ax0=dm(Prog_Flag_Data);
	ay0=0x000F;
	ar=ax0 and ay0;
	sr=lshift ar by 12 (lo);
	dm(CODG)=sr0; ;// CODG = f1 f2 f3 f4 0000 0000 0000
	ax0=dm(encrypt);
	ay0=32; ;//bitul 5 adica al 5lea buton din sw este apasat .
	ar=ax0-ay0 ;
	if eq jump Q31;
	ar=4;
	dm(Q)=ar;
	dm(cnt4)=ar;
	rts;
	
	
Q31:
	;//facem encoding pe rezultat a.i sa putem proteja datele chiar daca sunt
	;//sub forma unor sinuri  raspunsul  primit este codat sub alta forma
		;// o secventa 00 --->0  un sin de frecventa 0
		;// o secventa 01 --->01  un sin de frecventa 0 un sin de f1
		;// o secventa 10 --->011  un sin de frecventa 0 doua sinusiri de f1
		;// o secventa 11 --->0111  un sin de frecventa 0 3 sinusuri de f1
	ar=0;
	dm(nr_sin_codate) = ar;
	ar=dm(CODG);
	sr=lshift ar by 2 (lo);
	;//avem in sr1 cei doi biti
	ax0 = sr1;
	ay0=0;
	ar=ax0-ay0;
	if eq call cod0; ;// un cod de 00
	ay0=1;
	ar=ax0-ay0;
	if eq call cod1; ;// un cod de 01
	ay0=2;
	ar=ax0-ay0;
	if eq call cod2; ;// un cod de 011
	ay0=3;
	ar=ax0-ay0;
	if eq call cod3; ;// un cod de 0111
	ax0 = sr0;
	;//compar cu bitii din sr0;
	ay0=0;
	ar=ax0-ay0;
	if eq call cod00; ;// un cod de 00
	ay0=0x4000;
	ar=ax0-ay0;
	if eq call cod11; ;// un cod de 01
	ay0=0x8000;
	ar=ax0-ay0;
	if eq call cod22; ;// un cod de 011
	ay0=0xC000;
	ar=ax0-ay0;
	if eq call cod33; ;// un cod de 0111
	;//acum formam cuvantul final.
	;//dimensiunea lui e salvata in nr_sinusoide de codat.
	ax0= dm(nr_sin_codate);
	ay0=2;
	ar=ax0-ay0;
	if eq call shift14; ;// un cod de 00
	ay0=3;
	ar=ax0-ay0;
	if eq call shift13; ;// un cod de 00
	ay0=4;
	ar=ax0-ay0;
	if eq call shift12; ;// un cod de 00
	ay0=5;
	ar=ax0-ay0;
	if eq call shift11; ;// un cod de 00
	ay0=6;
	ar=ax0-ay0;
	if eq call shift10; ;// un cod de 00
	ay0=7;
	ar=ax0-ay0;
	if eq call shift9; ;// un cod de 00
	ay0=8;
	ar=ax0-ay0;
	if eq call shift8; ;// un cod de 00
	ar=4;
	dm(Q)=ar;
	rts;
	
shift14:
	ar= dm(CODG);
	sr=lshift ar by 14(lo);
	ar=sr0;
	dm(CODG)= ar;
	rts;


shift13:
	ar= dm(CODG);
	sr=lshift ar by 3(lo);
	ar=sr0;
	dm(CODG)= ar;
	rts;
	
	
shift12:
	ar= dm(CODG);
	sr=lshift ar by 12(lo);
	ar=sr0;
	dm(CODG)= ar;
	rts;
	
	
shift11:
	ar= dm(CODG);
	sr=lshift ar by 11(lo);
	ar=sr0;
	dm(CODG)= ar;
	rts;
	
	
shift10:
	ar= dm(CODG);
	sr=lshift ar by 10(lo);
	ar=sr0;
	dm(CODG)= ar;
	;//COD G de forma f0 f1 f2 f2 f4 f5 0 0 0 0.... Numarul este varaiabil de la 2 la 8 sinusoide.
	rts;
	
	
shift9:
	ar= dm(CODG);
	sr=lshift ar by 9(lo);
	ar=sr0;
	dm(CODG)= ar;
	rts;
	
	
shift8:
	ar= dm(CODG);
	sr=lshift ar by 8(lo);
	ar=sr0;
	dm(CODG)= ar;
	rts;
	
	
cod0:
	ar=dm(nr_sin_codate);
	ar=ar+1;
	dm(nr_sin_codate) = ar;
	ar=0;
	dm(cg1)=ar;
	rts;
	
	
cod00:
	ar=dm(nr_sin_codate);
	ar=ar+1;
	dm(nr_sin_codate) = ar;
	ar=dm(cg1);
	sr=lshift ar by 1(lo);
	ax0=sr0;
	ay0=0;
	ar=ax0+ay0;
	dm(CODG)=ar;
	rts;
	
	
cod1:
	ar=dm(nr_sin_codate);
	ar=ar+2;
	dm(nr_sin_codate) = ar;
	ar=1;
	dm(cg1)=ar;
	rts;
	
	
cod11:
	ar=dm(nr_sin_codate);
	ar=ar+2;
	dm(nr_sin_codate) = ar;
	ar=dm(cg1);
	sr=lshift ar by 2(lo);
	ax0=sr0;
	ay0=1;
	ar=ax0+ay0;
	dm(CODG)=ar;
	rts;
	
	
cod2:
	ar=dm(nr_sin_codate);
	ar=ar+3;
	dm(nr_sin_codate) = ar;
	ar=3;
	dm(cg1)=ar;
	rts;
	
	
cod22:
	ar=dm(nr_sin_codate);
	ar=ar+3;
	dm(nr_sin_codate) = ar;
	ar=dm(cg1);
	sr=lshift ar by 3(lo);
	ax0=sr0;
	ay0=3;
	ar=ax0+ay0;
	dm(CODG)=ar;
	rts;
	
	
cod3:
	ar=dm(nr_sin_codate);
	ar=ar+4;
	dm(nr_sin_codate) = ar;
	ar=7;
	dm(cg1)=ar;
	rts;
	
	
cod33:
	ar=dm(nr_sin_codate);
	ar=ar+4;
	dm(nr_sin_codate) = ar;
	ar=dm(cg1);
	sr=lshift ar by 4(lo);
	ax0=sr0;
	ay0=7;
	ar=ax0+ay0;
	dm(CODG)=ar;
	rts;
	
	
Q4:
	;// se genereaza 4 x 205 esantioane de sin
	ar=dm(cnt3);
	ar= pass ar;
	if ne jump gen;
	;// determina frecventa
	;// CODG - f1 f2 f3 f4
	ar=dm(CODG);
	sr=lshift ar by 1 (lo);
	dm(CODG)=sr0;
	ay0=0x01;
	ar=sr1 and ay0; ;// ar= frecventa de generat 1 sau 0
	dm(fc)=ar;
	gen:
	ar=dm(fc);
	ar=pass ar;
	if eq call generator0;
	ar=dm(fc);
	ar=pass ar;
	if ne call generator1;
	ar=dm(cnt3);
	ar=ar+1;
	dm(cnt3)=ar;
	ay0=N;
	ar=ar-ay0;
	if ne rts;
	ar=0;
	dm(cnt3)=ar;
	call init_generator;
	call set_encrypt;
	call set_durata;
	ar=dm(CNTGen);
	ar=ar+1;
	dm(CNTGen)=ar;
	ay0=dm(nr_sin_codate);
	ar=ar-ay0;
	if ne rts;
	ar=0;
	dm(CNTGen)=ar;
	dm(Q)=ar;
	rts;
	init_receptor:
	call setup;
	call restart;
	i0=Q1Q2_buff;
	;//i5=coefs;
	rts;
	
	
set_durata:
	ax1=dm(switch);
	ay0 = 0x40; ;//pentru a obtine frecventa de 0
	ar = ax1 AND ay0; ;// frecventa de 0
	ax0=ar;
	ay0=0;
	ar=ax0-ay0;
	if eq call durata5t; ;// durata sincronizare este de 6T.
	ay0=0x04;
	ar=ax0-ay0;
	if eq call durata8t; ;// durata este de 6T.
	rts;
	
	
durata5t:
	ax0= 820; ;// 4n esantioane
	dm(Ndurata1) = ax0;
	ax0= 204; ;// N-1 esantioane;
	dm(Ndurata2) = ax0;
	rts;
	durata8t:
	ax0= 1230; ;// 6n esantioane
	dm(Ndurata1) = ax0;
	ax0= 409; ;// 2N-1 esantioane;
	dm(Ndurata2) = ax0;
	rts;
	
	
init_generator:
	si=0;
	dm(sum0)=si;
	dm(sum1)=si;
	ax1=dm(switch);
	ay0 = 0x03; ;//pentru a obtine frecventa de 0
	ar = ax1 AND ay0; ;// frecventa de 0
	ay0=0;
	ax0=ar;
	ar=ax0-ay0 ;
	if eq jump f0_697; ;// frecventa de 697 hz comb 00
	ay0=1;
	ar=ax0-ay0 ;
	if eq jump f0_770; ;// frecventa de 697 hz comb 01
	ay0=2;
	ar=ax0-ay0 ;
	if eq jump f0_852; ;// frecventa de 697 hz comb 10
	ay0=3;
	ar=ax0-ay0 ;
	if eq jump f0_941; ;// frecventa de 697 hz comb 11
	rts;
	
	
f0_697:
	si=0x2b9; ;// frecveta in hexa
	dm(hertz0)=si;
	SR1 = 0x01;
	dm(outcd_f0_test)= sr1; ;// 2 la 0
	jump init_f1;
	
f0_770:
	si=0x302;
	dm(hertz0)=si;
	SR1=0x0002;
	dm(outcd_f0_test)= SR1;;// 2 la 1
	jump init_f1;
	
f0_852:
	si=0x354;
	dm(hertz0)=si;
	SR1=0x0004;
	dm(outcd_f0_test)=SR1; ;// 2 la 2
	jump init_f1;
	f0_941:
	si=0x3ad;
	dm(hertz0)=si;
	SR1=0x0008;
	dm(outcd_f0_test)= sr1;;// 2 la 3
	jump init_f1;
	init_f1:
	;// in ax1 avem citit switchul deci nu mai avem nevoie de alta
	;//citire
	ay0 = 0x0c; ;//pentru a obtine frecventa de 1
	ar = ax1 AND ay0; ;// frecventa de 1
	ay0=0;
	ax0=ar;
	ar=ax0-ay0 ;
	if eq jump f1_1209; ;// frecventa de 1209 hz comb 0000
	ay0=4;
	ar=ax0-ay0 ;
	if eq jump f1_1336; ;// frecventa de 1336 hz comb 0100
	ay0=8;
	ar=ax0-ay0 ;
	if eq jump f1_1477; ;// frecventa de 697 hz comb 1000
	ay0=12;
	ar=ax0-ay0 ;
	if eq jump f1_1633; ;// frecventa de 697 hz comb 11
	rts;
	
	
f1_1209:
	si=0x489;
	dm(hertz1)=si;
	SR1=0x0010;
	dm(outcd_f1_test)= sr1;;// 2 la puterea 4
	rts;
	
f1_1336:
	si=0x538;
	dm(hertz1)=si;
	SR1=0x0020;
	dm(outcd_f1_test)= sr1;;// 2 la puterea 5
	rts;
	
f1_1477:
	si=0x5c5;
	dm(hertz1)=si;
	SR1=0x0040;
	dm(outcd_f1_test)= sr1;;// 2 la puterea 5
	rts;
	
f1_1633:
	si=0x661;
	dm(hertz1)=si;
	SR1=0x0080;
	dm(outcd_f1_test)= sr1;;// 2 la puterea 6
	rts;
	
	
set_encrypt:
	ax1=dm(switch);
	ay0 = 0x20 ; ;//avem nevoie de bitul 5 adica de al 5lea buton;
	ar = ax1 AND ay0;
	dm(encrypt) = ar;
	rts;
	
receptor:
	;//si=dm(rx_buf+2); ;//{ citeste esantionul curent }
	si=dm(in);
	sr=ashift si by scale (hi);
	dm(in_sample)=sr1; ;//{ stocarea esantionului de intrare }

;//{---------- DECREMENTAREA CONTORULUI DE ESANTIOANE ----------------------------}
;//{ }
decN: ay0=dm(countN);
	ar=ay0-1;
	dm(countN)=ar;
	if lt jump skip_backs;
;//{----------- F A Z A F E E D B A C K ---------------------------------------}
;//{ }
feedback: ay1=dm(in_sample); ;//{ extrage esantionul la intrare AY1=1.15}
	cntr=tones;
	do backs until ce;
		;//mx0=dm(i0,m0), my0=pm(i5,m4); ;//{extrage Q1 si COEF Q1=1.15, COEF=2.14}
		mx0=dm(i0,m0), my0=pm(i7,m4); ;//{extrage Q1 si COEF Q1=1.15, COEF=2.14}
		;//mr=mx0*my0(rnd), ay0=dm(i0,m1); ;//{inmulteste, get Q2 MR=2.30, Q2=1.15}
		mr=mx0*my0(rnd), ay0=dm(i0,m2); ;//{inmulteste, get Q2 MR=2.30, Q2=1.15}
		sr=ashift mr1 by 1 (hi); ;//{schimba 2.30 in 1.15 }
		ar=sr1-ay0; ;//{Q1*COEF - Q2 AR=1.15}
		ar=ar+ay1; ;//{Q1*COEF - Q2 + intrarea AR=1.15}
		dm(i0,m0)=ar; ;//{rezultatul = noul Q1 }
	backs: dm(i0,m0)=mx0; ;//{vechiul Q1 = noul Q2 }
		jump end;;
;//{---------- C A N D F A Z A F E E D B A C K E S T E G A T A -------------}
;//{ }
skip_backs:
	call feedforward;
	call test_and_output;
	call restart;
	;//
	ar=1;
	dm(REC_Rdy)=ar; ;// receptor gata
	;//
	end: nop;
	rts;
	
	
generator0:
	ay0=dm(sum0);
	si=dm(hertz0);
	sr=ashift si by 3 (hi);
	my0=0x4189;
	mr=sr1*my0 (rnd);
	sr=ashift mr1 by 1 (hi);
	ar=sr1+ay0;
	dm(sum0)=ar;
	ax0=ar;
	m3=1;l3=0;
	call sin; ;//in ar - > esantionul DTMF
	;//
	dm(tx_buf+2)=ar;
	;//
	rts;
	
	
generator1:
	ay0=dm(sum1);
	si=dm(hertz1);
	sr=ashift si by 3 (hi);
	my0=0x4189;
	mr=sr1*my0 (rnd);
	sr=ashift mr1 by 1 (hi);
	ar=sr1+ay0;
	dm(sum1)=ar;
	ax0=ar;
	m3=1;l3=0;
	call sin; ;//in ar - > esantionul DTMF
	;//
	dm(tx_buf+2)=ar;
	;//
	rts;
	;//
	
setup:
	l0 = tones_x_2;
	l1 = 0;
	l2 = 0;
	l3 = 0;
	l4 = 0;
	;//l5 = tones;
	l7=tones;
	;// l6 = 0;
	m0 = 1;
	;//m1 = -1;
	m2=-1;
	m4 = 1;
	;//icntl=b#01111;
	rts;
	/*
	
	
{ reseteaza pointerii,reseteaza valorile contorului }
{ aduce bufferele Goertzel feedback la zero, etc }
{ */
restart: i0=Q1Q2_buff;
	;//i5=coefs;
	i7=coefs;
	cntr=tones_x_2;
	do zloop until ce;
	zloop: dm(i0,m0)=0;
	ax0=N;
	dm(countN)=ax0;
	rts;
;//{%%%%%%%%%%% F A Z A F E E D F O R W A R D %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%}
;//{ }
feedforward: cntr=tones;
	i2=mnsqr;
	do forwards until ce;
	mx0=dm(i0,m0); ;//{ extrage doua copii Q1 1.15 }
	my0=mx0;
	mx1=dm(i0,m0); ;//{ extrage doua copii Q2 1.15 }
	my1=mx1;
	;//ar=pm(i5,m4); ;//{ extrage COEF 2.14 }
	ar=pm(i7,m4); ;//{ extrage COEF 2.14 }
	mr=0;
	mf=mx0*my1(rnd); ;//{ Q1*Q2 1.15 }
	mr=mr-ar*mf(rnd); ;//{ -Q1*Q2*COEF 2.14 }
	sr=ashift mr1 by 1 (hi); ;//{ 2.14 -> 1.15 format conv. 1.15 }
	mr=0;
	mr1=sr1;
	mr=mr+mx0*my0(ss); ;//{ Q1*Q1 + -Q1*Q2*COEF 1.15 }
	mr=mr+mx1*my1(rnd); ;//{ Q1*Q1 + Q2*Q2 + -Q1*Q2*COEF 1.15 }
	forwards: dm(i2,m0)=mr1; ;//{ stocheaza in bufferul mnsqr 1.15 }
	rts;
;//{%%%%%% Testarea nivelelor si a codului de iesire %%%%%%%%%%%%%%%%%%%%%%%%%%%}
;//{ }
test_and_output: i3=bits;
	i1=min_tone_level;
	i2=mnsqr;
	cntr=tones;
	af=pass 0;
	do thresholds until ce;
	ax1=dm(i3,m0); ;//{ preia pozitia bitilor la set/clear }
	ax0=dm(i2,m0); ;//{ preia valoarea calculata tone mnsqr }
	ay0=dm(i1,m0); ;//{ preia valoarea de prag min tone level }
	ar=ax0-ay0; ;//{ mnsqr - min_tone_level }
	thresholds: if gt af=ax1 or af;
	ar=pass af;
	dm(outcode)=ar; ;//{ scrie rezultatul la iesire }
	rts;
	;//
	
/*
	Sine Approximation
	Y = Sin(x)
	Calling Parameters
	AX0 = x in scaled 1.15 format
	M3 = 1
	L3 = 0
	Return Values
	AR = y in 1.15 format
	Altered Registers
	AY0,AF,AR,MY1,MX1,MF,MR,SR,I3
*/

sin: I3=sin_coeff; ;// Pointer to coeff. buffer
	AY0=0x4000;
	AR=AX0, AF=AX0 AND AY0; ;// Check 2nd or 4th quad.
	IF NE AR=-AX0; ;// If yes, negate input
	AY0=0x7FFF;
	AR=AR AND AY0; ;// Remove sign bit
	MY1=AR;
	MF=AR*MY1 (RND), MX1=DM(I3,M3); ;// MF = x**2
	MR=MX1*MY1 (SS), MX1=DM(I3,M3); ;// MR = C1*x
	CNTR=3;
	DO approx UNTIL CE;
	MR=MR+MX1*MF (SS);
approx: 	MF=AR*MF (RND), MX1=DM(I3,M3);
	MR=MR+MX1*MF (SS);
	SR=ASHIFT MR1 BY 3 (HI);
	SR=SR OR LSHIFT MR0 BY 3 (LO); ;// Convert to 1.15 format
	AR=PASS SR1;
	IF LT AR=PASS AY0; ;// Saturate if needed
	AF=PASS AX0;
	IF LT AR=-AR; ;// Negate output if needed
	RTS;