/*******************************************************
This program was created by the CodeWizardAVR V3.38
Automatic Program Generator
© Copyright 1998-2019 Pavel Haiduc, HP InfoTech s.r.l.
http://www.hpinfotech.com
Project : P2
Version :
Date    : 4/11/2020
Author  : IonutS
Company :
Comments:
Chip type               : AT90S8515
AVR Core Clock frequency: 4.000000 MHz
Memory model            : Small
External RAM size       : 0
Data Stack size         : 128
 *******************************************************/

#include <90s8515.h>
#include <delay.h>

// Declare your global variables here
int Q=4; //variabila stare.
int in, cnt=0,i,bl,cnt1=0;
char tmp;
int pass[3]= {1, 2, 3};
int parola[3];
int vit[7]={150,125, 100, 75, 50, 25,1};


char read_keyboard(void)
{
    // line 0 - PA0, line 1 - PA1, line 2 - PA2, line 3 - PA3 - outputs
    char scan[4]={0xFE,0xFD,0xFB, 0xF7};
    char row,col;
    char cod=0xFF;
    for (row=0; row<4; row++)
    {
        PORTA=scan[row];
        delay_us(1);
        // col 0 - PA4, col 1 - PA5, col 2 - PA6, col 3 - PA7 - inputs
        col=PINA>>4;
        if (col!=0x0F)
        {
            if (col==0x0E) col=0;
            if (col==0x0D) col=1;
            if (col==0x0B) col=2;
            if (col==0x07) col=3;
            cod=4*row+col;
            break;
        }
    }
    return cod;
}

void write_LED(char a)
{
    // write PORTC bits 7-4 with a 4 bits value a3-a0
    //activ in 1 doar la leduri
    char val;
    char x=1;
    val=a & 0x0F;
    x = x << val;

    PORTC=(PORTC)  | (x << 4);
}

void write_LEDbin(char a)
{
    // write PORTC bits 7-4 with a 4 bits value a3-a0
    //activ in 1 doar la leduri
    //a sa nu depaseasca 15.
    PORTC =0x00;   //am stins tot ce era inainte
    PORTC = a<<4;
}


void delete_LED(char a)
{
    // write PORTC bits 7-4 with a 4 bits value a3-a0
    //activ in 1 doar la leduri
    char val;
    char x=1;
    val=a & 0x0F;
    x = x << val;
    x= x<<4;
    x= ~x ;

    //modificam doar pozitia care ne interezeaza
    PORTC=PORTC & (x);
}


void write_PF(char a)
{
    // write PORTB bits 7-4 with a 4 bits value a7-a4
    char val;
    val=a & 0x0F;
    PORTB=(PORTB & 0x0F) | (val<<4);

}

void error()
{
    char i=3,val;
    val=PINC;
    PORTC=0x00;
    while(i)
    {
        PORTC=PORTC | 0xF0;
        delay_ms(15);
        PORTC=PORTC & 0x00;
        i--;
    }
    PORTC=val;
}



// Timer 0 overflow interrupt service routine
interrupt [TIM0_OVF] void timer0_ovf_isr(void)
{
    // Reinitialize Timer 0 value
    TCNT0=0xAF;
    // Place your code here
    switch (Q)
    {
        case 0:
            cnt=0;
            in=PINB;
            in = in & 0x0F;
            if(in == 9)
            {
                for(i=0 ; i<3 ; i++)
                {
                    while(1)
                    {
                        parola[i]= read_keyboard();
                        if(parola[i]!=0xFF)
                        {
                            break;
                        }
                    }

                    while(1)
                    {
                        if(read_keyboard()==0xFF)
                            break;
                    }
                }

                for(i=0 ; i<3 ; i++)
                {
                    if(parola[i]== pass[i])
                        cnt++;
                }
            }

            if(cnt == 3 )
            {
                write_PF(5);  //puteam sa folosim alta variabila...
                Q=1;      //se activeaza avr
            }
            else {
                write_PF(7);
            }
            break;

            //centru de comanda
        case 1:
            in=PINB;
            in = in & 0x0F;
            if(in == 1) {Q=2;}       //aprindere un led
            else if(in == 2) {Q=3;}  //stingere un led
            else if(in == 3) {Q=4;}  //blink un led perioada costanta
            else if(in == 4) {Q=5;}  // aprindere leduri de la stanga la dreapta.
            else if(in == 5) {Q=6;}  //aprindere de la dreoapta la staga.
            else if(in == 6) {Q=7;}  //aprinde 2 leduri alaturate/
            else if(in == 7) {Q=8;}  ///stinge 2 leduri alaturate
            else if(in == 8 || in ==0) {Q=9;}  //inactiv system
            else if(in == 9) {Q=1;
            write_PF(5);
            }        // default centru de comadnda deja sistemul e activ.
            else if(in == 10) {Q=10;} //blocare sistem   cu life points
            else if(in == 11) {Q=11;} //test linia 0
            else if(in == 12) {Q=12;} //test linia 1
            else if(in == 13) {Q=13;} //test linia 2
            else if(in == 14) {Q=14;} //test linia 3
            else if(in == 15) {Q=15;} //reinitializare sistem AVR
            break;

        case 2: // Aprindere un led  0-3
            //APRINDERE  un LED

            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            if(tmp== 0 || tmp == 1 || tmp == 2 || tmp == 3)
            {
                write_LED(tmp);
                tmp+=8; // ca sa dam raspunsul pentru DSP in formatul corect
                write_PF(tmp);  //raspuns catre DSP
                Q=1;
                break;
            }
            else {
                error();
                Q=2;
                break;
            }

        case 3:  //stingere un led 0-3

            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            if(tmp== 0 || tmp == 1 || tmp == 2 || tmp == 3)
            {
                delete_LED(tmp);
                tmp+=8; // ca sa dam raspunsul pentru DSP in formatul corect
                write_PF(tmp); //raspuns catre DSP
                Q=1;
                break;
            }
            else {
                error();
                Q=3;
                break;
            }


        case 4: //blink un led perioada constanta
            cnt = 5;
            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            Q=41;
            break;

        case 41:
            if(tmp== 0 || tmp == 1 || tmp == 2 || tmp == 3)
            {
                write_LED(tmp);
                Q=42;
                break;
            }
            else
            {
                error();
                Q=4;
                break;
            }
        case 42:
            cnt1++;
            if(cnt1==50)
            {
                cnt1=0;
                delete_LED(tmp);
                Q=43;
            }
            break;

        case 43:
            cnt1++;
            if(cnt1==50)
            {
                cnt1=0;
                write_LED(tmp);
                cnt--;
                if(cnt>0)
                    Q=41;
                else
                {
                    tmp+=8; // ca sa dam raspunsul pentru DSP in formatul corect
                    write_PF(tmp);
                    Q=1;
                    break;
                }
            }
            break;

        case 5:

            PORTC= 0x00; //STERGE TOT CE ERA INAINTE;
            i=3;
            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }


            if(tmp>=0 && tmp<=7)
                Q=51;
            else
            {
                error();
                Q=5;
            }
            break;

        case 51:
            write_LED(i);
            Q=52;
            if(i==0)
            {
                write_PF(tmp+8);
                Q=1;
            }
            break;

        case 52:
            cnt1++;
            if(cnt1==vit[tmp])
            {
                cnt1=0;
                i--;
                Q=51;
            }
            break;

        case 6:

            PORTC= 0x00; //STERGE TOT CE ERA INAINTE;
            i=0;
            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }


            if(tmp>=0 && tmp<=7)
                Q=61;
            else
            {
                error();
                Q=6;
            }
            break;

        case 61:
            write_LED(i);
            Q=62;
            if(i==3)
            {
                write_PF(tmp+8);
                Q=1;
            }
            break;

        case 62:
            cnt1++;
            if(cnt1==vit[tmp])
            {
                cnt1=0;
                i++;
                Q=61;
            }
            break;

        case 7:

            PORTC= 0x00; //STERGE TOT CE ERA INAINTE ca sa putem observa mai bine;
            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            if(tmp== 0 || tmp == 1 || tmp == 2 || tmp == 3)
            {
                if(tmp==3)
                {
                    write_LED(tmp);
                    write_LED(tmp-1);
                }
                else
                {
                    write_LED(tmp);
                    write_LED(tmp+1);
                }
                tmp+=8;
                write_PF(tmp);
                Q=1;
                break;
            }
            else
            {
                error();
                Q=7;
                break;
            }

        case 8:

            PORTC= 0xFF; //aprindem ledurile ca sa putem observa mai bine;
            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            if(tmp== 0 || tmp == 1 || tmp == 2 || tmp == 3)
            {
                if(tmp==3)
                {
                    delete_LED(tmp);
                    delete_LED(tmp-1);
                }
                else
                {
                    delete_LED(tmp);
                    delete_LED(tmp+1);
                }
                tmp+=8;
                write_PF(tmp);
                Q=1;
            }
            else
            {
                error();
                Q=8;
                break;
            }


            break;

        case 9: //sistem inactiv.

            write_PF(7);
            Q=0;

            break;

        case 10:

            cnt=0;
            for(i=0 ; i<3 ; i++)
            {
                while(1)
                {
                    parola[i]= read_keyboard();
                    if(parola[i]!=0xFF)
                    {
                        break;
                    }
                }

                while(1)
                {
                    if(read_keyboard()==0xFF)
                        break;
                }
            }

            for(i=0 ; i<3 ; i++)
            {
                if(parola[i]== pass[i])
                    cnt++;
            }

            if(cnt==3)
            {
                Q=99 ; // BLOCAT
                write_PF(15);
                break;
            }
            else
            {
                Q=1;
                write_PF(5);
            }

            break;

        case 99:

            PORTC=0xE0;
            while(bl>0)
            {
                bl=3;
                cnt=0;
                for(i=0 ; i<3 ; i++)
                {
                    while(1)
                    {
                        parola[i]= read_keyboard();
                        if(parola[i]!=0xFF)
                            break;
                    }
                    while(1)
                    {
                        if(read_keyboard()==0xFF)
                            break;
                    }
                }
                for(i=0; i<3 ; i++)
                    if(parola[i] == pass[i])
                        cnt++;
                if(cnt == 3)
                {
                    Q=1;
                    write_PF(5);
                    break;
                }
                else
                {
                    delete_LED(bl);
                    bl--;
                }
            }
            if(bl==0)
            {
                Q =0;
                write_PF(7);
            }

            break;

        case 11:

            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            if(tmp== 0 || tmp == 1 || tmp == 2 || tmp == 3)
            {
                write_LEDbin(tmp);
                tmp = tmp%4; // de aici rezulta codul coloanei
                write_PF(tmp);
                Q=1;
                break;
            }
            else
            {
                error();
                Q=11;
            }

        case 12:

            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            if(tmp== 4 || tmp == 5 || tmp == 6 || tmp == 7)
            {
                write_LEDbin(tmp);
                tmp = tmp%4; // de aici rezulta codul coloanei
                write_PF(tmp);
                Q=1;
                break;
            }
            else
            {
                error();
                Q=12;
            }

        case 13:

            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            if(tmp== 8 || tmp == 9 || tmp == 10 || tmp == 11)
            {
                write_LEDbin(tmp);
                tmp = tmp%4; // de aici rezulta codul coloanei
                write_PF(tmp);
                Q=1;
                break;
            }
            else
            {
                error();
                Q=13;
            }

        case 14:

            while(1)
            {
                tmp= read_keyboard();
                if(tmp!=0xFF)
                    break;
            }
            while(1)
            {
                if(read_keyboard()==0xFF)
                    break;
            }
            if(tmp== 12 || tmp == 13 || tmp == 14 || tmp == 15)
            {
                write_LEDbin(tmp);
                tmp = tmp%4; // de aici rezulta codul coloanei
                write_PF(tmp);
                Q=1;
                break;
            }
            else
            {
                error();
                Q=14;
            }

        case 15:

            PORTC = 0x00; //oprim toate ledurile
            write_PF(6);
            Q=0;
            break;

    }
}
void main(void)
{
    // Declare your local variables here

    // Input/Output Ports initialization
    // Port A initialization
    // Function: Bit7=In Bit6=In Bit5=In Bit4=In Bit3=Out Bit2=Out Bit1=Out Bit0=Out
    DDRA=(0<<DDA7) | (0<<DDA6) | (0<<DDA5) | (0<<DDA4) | (1<<DDA3) | (1<<DDA2) | (1<<DDA1) | (1<<DDA0);
    // State: Bit7=P Bit6=P Bit5=P Bit4=P Bit3=1 Bit2=1 Bit1=1 Bit0=1
    PORTA=(1<<PORTA7) | (1<<PORTA6) | (1<<PORTA5) | (1<<PORTA4) | (1<<PORTA3) | (1<<PORTA2) | (1<<PORTA1) | (1<<PORTA0);

    // Port B initialization
    // Function: Bit7=Out Bit6=Out Bit5=Out Bit4=Out Bit3=In Bit2=In Bit1=In Bit0=In
    DDRB=(1<<DDB7) | (1<<DDB6) | (1<<DDB5) | (1<<DDB4) | (0<<DDB3) | (0<<DDB2) | (0<<DDB1) | (0<<DDB0);
    // State: Bit7=1 Bit6=1 Bit5=1 Bit4=1 Bit3=P Bit2=P Bit1=P Bit0=P
    PORTB=(1<<PORTB7) | (1<<PORTB6) | (1<<PORTB5) | (1<<PORTB4) | (1<<PORTB3) | (1<<PORTB2) | (1<<PORTB1) | (1<<PORTB0);

    // Port C initialization
    // Function: Bit7=Out Bit6=Out Bit5=Out Bit4=Out Bit3=In Bit2=In Bit1=In Bit0=In
    DDRC=(1<<DDC7) | (1<<DDC6) | (1<<DDC5) | (1<<DDC4) | (0<<DDC3) | (0<<DDC2) | (0<<DDC1) | (0<<DDC0);
    // State: Bit7=1 Bit6=1 Bit5=1 Bit4=1 Bit3=P Bit2=P Bit1=P Bit0=P
    PORTC=(0<<PORTC7) | (0<<PORTC6) | (0<<PORTC5) | (0<<PORTC4) | (0<<PORTC3) | (0<<PORTC2) | (0<<PORTC1) | (0<<PORTC0);

    // Port D initialization
    // Function: Bit7=In Bit6=In Bit5=In Bit4=In Bit3=In Bit2=In Bit1=In Bit0=In
    DDRD=(0<<DDD7) | (0<<DDD6) | (0<<DDD5) | (0<<DDD4) | (0<<DDD3) | (0<<DDD2) | (0<<DDD1) | (0<<DDD0);
    // State: Bit7=T Bit6=T Bit5=T Bit4=T Bit3=T Bit2=T Bit1=T Bit0=T
    PORTD=(0<<PORTD7) | (0<<PORTD6) | (0<<PORTD5) | (0<<PORTD4) | (0<<PORTD3) | (0<<PORTD2) | (0<<PORTD1) | (0<<PORTD0);

    // Timer/Counter 0 initialization
    // Clock source: System Clock
    // Clock value: 3.906 kHz
    TCCR0=(1<<CS02) | (0<<CS01) | (1<<CS00);
    TCNT0=0xAF;

    // Timer/Counter 1 initialization
    // Clock source: System Clock
    // Clock value: Timer1 Stopped
    // Mode: Normal top=0xFFFF
    // OC1A output: Disconnected
    // OC1B output: Disconnected
    // Noise Canceler: Off
    // Input Capture on Falling Edge
    // Timer1 Overflow Interrupt: Off
    // Input Capture Interrupt: Off
    // Compare A Match Interrupt: Off
    // Compare B Match Interrupt: Off
    TCCR1A=(0<<COM1A1) | (0<<COM1A0) | (0<<COM1B1) | (0<<COM1B0) | (0<<PWM11) | (0<<PWM10);
    TCCR1B=(0<<ICNC1) | (0<<ICES1) | (0<<CTC1) | (0<<CS12) | (0<<CS11) | (0<<CS10);
    TCNT1H=0x00;
    TCNT1L=0x00;
    OCR1AH=0x00;
    OCR1AL=0x00;
    OCR1BH=0x00;
    OCR1BL=0x00;

    // Timer(s)/Counter(s) Interrupt(s) initialization
    TIMSK=(0<<TOIE1) | (0<<OCIE1A) | (0<<OCIE1B) | (0<<TICIE1) | (1<<TOIE0);

    // External Interrupt(s) initialization
    // INT0: Off
    // INT1: Off
    GIMSK=(0<<INT1) | (0<<INT0);
    MCUCR=(0<<ISC11) | (0<<ISC10) | (0<<ISC01) | (0<<ISC00);

    // UART initialization
    // UART disabled
    UCR=(0<<RXCIE) | (0<<TXCIE) | (0<<UDRIE) | (0<<RXEN) | (0<<TXEN) | (0<<CHR9) | (0<<RXB8) | (0<<TXB8);

    // Analog Comparator initialization
    // Analog Comparator: Off
    // The Analog Comparator's positive input is
    // connected to the AIN0 pin
    // The Analog Comparator's negative input is
    // connected to the AIN1 pin
    ACSR=(1<<ACD) | (0<<ACO) | (0<<ACI) | (0<<ACIE) | (0<<ACIC) | (0<<ACIS1) | (0<<ACIS0);

    // SPI initialization
    // SPI disabled
    SPCR=(0<<SPIE) | (0<<SPE) | (0<<DORD) | (0<<MSTR) | (0<<CPOL) | (0<<CPHA) | (0<<SPR1) | (0<<SPR0);


    // Globally enable interrupts
#asm("sei")

    while (1)
    {
        // Place your code here

    }
