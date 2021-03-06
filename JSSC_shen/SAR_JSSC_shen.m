function [adco,Energy_mean]=SAR_JSSC_shen
%Input is the bits of the ADC, N must be a even number and usually larger than 4.
Vref=1;%We define the V-suply=1V, our bianry search range is thus -1v~+1V
N=16;
len=2^15-8; % the Scale of the output matrix (adco) is thus len*N.
LSB=2*Vref/2^N; %Define LSB as the resolution.
LSB=round(LSB*10^N)/10^N;
fs=100;  % frequency of sampling clock, in Mhz   
fin=fs*(0.125*len-17)/len;
ground=0;
Vcm=1/2*Vref;%The common mode voltage is defined as half of the Vref
sig_c=0;%Define the Standard Deviation (Std) of an unit capacitor
comp_error=0;%Define the posibility of an error decision in the SAR process
C_norp3=[16 16 8 4 2 1 1];%C_norp3(2)-Redun3; C_norp3(6:15)-10LSBs
C_norp2=[8 8 4 2 1];%C_norp2(2)-Redun2
C_norp1=[64, 32, 16, 8, 8, 4, 2, 1];%C_norp1(5)-Redun1
C_devp3=sig_c*C_norp3.*randn(1,7);
C_devp2=sig_c*C_norp2.*randn(1,5);
C_devp1=sig_c*C_norp1.*randn(1,8);
C_brip3_2=(sum(C_norp3)/(32-1))*(1+randn(1,1)*sig_c);%The bridge cap between array 3 and array 2
C_brip2_1=((sum(C_norp2)+(sum(C_norp3)/32))/(16-1))*(1+randn(1,1)*sig_c);%The bridge cap between array 2 and array 1
C_p3=C_norp3+C_devp3;
C_p2=C_norp2+C_devp2;
C_p1=C_norp1+C_devp1;
C_p3tot=sum(C_p3);
C_p2tot=sum(C_p2);
C_p1tot=sum(C_p1);
outerfactor_p3_2=(C_p3tot*C_brip3_2)/(C_p3tot+C_brip3_2);
outerfactor_p2_1=((C_p2tot+outerfactor_p3_2)*C_brip2_1)/(C_p2tot+outerfactor_p3_2+C_brip2_1);
Cp=[C_p1,C_p2/(C_p2tot+outerfactor_p3_2)*outerfactor_p2_1,C_p3/C_p3tot*outerfactor_p3_2/(C_p2tot+outerfactor_p3_2)*outerfactor_p2_1];
%you can check the weight by delete the ";".
C_brin3_2=(sum(C_norp3)/(32-1))*(1+randn(1,1)*sig_c);%The bridge cap between array 3 and array 2
C_brin2_1=((sum(C_norp2)+(sum(C_norp3)/32))/(16-1))*(1+randn(1,1)*sig_c);%The bridge cap between array 2 and array 1
C_n3=C_p3;
C_n2=C_p2;
C_n1=C_p1;
C_n3tot=sum(C_n3);
C_n2tot=sum(C_n2);
C_n1tot=sum(C_n1);
outerfactor_n3_2=(C_n3tot*C_brin3_2)/(C_n3tot+C_brin3_2);
outerfactor_n2_1=((C_n2tot+outerfactor_n3_2)*C_brin2_1)/(C_n2tot+outerfactor_n3_2+C_brin2_1);
Cn=[C_n1,C_n2/(C_n2tot+outerfactor_n3_2)*outerfactor_n2_1,C_n3/C_n3tot*outerfactor_n3_2/(C_n2tot+outerfactor_n3_2)*outerfactor_n2_1];
Cp_tot=sum(Cp);%Total Capacitance of the Capacitive Array
Cn_tot=sum(Cn);
factor=(Cp_tot+Cn_tot-Cp(5)-Cp(10)-Cp(15)-Cn(5)-Cn(10)-Cn(15))/(Cp_tot+Cn_tot);
adco=[];
E=[];
for t=(0:len-1)*(1/fs)
A=zeros(1,19);
Vin=Vref*factor*sin(2*pi*fin*t); % Our input is an sinusoidal wave
MSB3=Flash_JSSC_shen(Vin,Vref);
Vinp=Vcm+0.5*Vin;
Vinn=Vcm-0.5*Vin;
Ft=zeros(20,1);%Define the Switch on the top side array, equals to 0 means they connect to GND, and 1 means they connect to Vref
Fb=zeros(20,1);
A(1:3)=MSB3;
Ft(1:3)=MSB3;
Ft(4)=1;% first step, connect C_1t to Vref, others to GND
Fb=1-Ft;%complementary characteristic
Vxp=Vcm-Vinp+Cp*Ft*Vref/Cp_tot;%The bootstrap characteristics proposed in Liu et al.'s work
Vxn=Vcm-Vinn+Cn*Fb*Vref/Cn_tot;
Energy=Cp*(abs(Vxp*ones(20,1)-Ft*Vref-(Vcm-Vinp)*ones(20,1)).^2)+Cn*(abs(Vxn*ones(20,1)-Fb*Vref-(Vcm-Vinn)*ones(20,1)).^2);%Energy consumption
old_Ft=Ft;
old_Fb=Fb;
if err_compare(Vxp,Vxn,comp_error)==1
    A(4)=0;%MSB output
    Ft(4)=0;
    Ft(5)=1;
    Fb=1-Ft;
else
    A(4)=1;
    Ft(5)=1;
    Fb=1-Ft;
end
new_Vxp=Vcm-Vinp+Cp*Ft*Vref/Cp_tot;
new_Vxn=Vcm-Vinn+Cn*Fb*Vref/Cn_tot;
Energy=Energy + Cp*(abs((new_Vxp*ones(20,1)-Ft*Vref)-(Vxp*ones(20,1)-old_Ft*Vref)).^2) + Cn*(abs((new_Vxn*ones(20,1)-Fb*Vref)-(Vxn*ones(20,1)-old_Fb*Vref)).^2);
%Delta_Energy= capacitance* (Voltage_new-Voltage_old)^2
for i=4:18
    Vxp=Vcm-Vinp+Cp*Ft*Vref/Cp_tot;
    Vxn=Vcm-Vinn+Cn*Fb*Vref/Cn_tot;
    old_Ft=Ft;
    old_Fb=Fb;
    if err_compare(Vxp,Vxn,comp_error)==1
        if i==18
            A(i+1)=0;
        else
            A(i+1)=0;
            Ft(i+1)=0;
            Ft(i+2)=1;
            Fb=1-Ft;
        end
    else
         if i==18
            A(i+1)=1;
        else
            A(i+1)=1;
            Ft(i+2)=1;
            Fb=1-Ft;
        end
    end
    new_Vxp=Vcm-Vinp+Cp*Ft*Vref/Cp_tot;
    new_Vxn=Vcm-Vinn+Cn*Fb*Vref/Cn_tot;
    if i<18
    Energy=Energy + Cp*(abs((new_Vxp*ones(20,1)-Ft*Vref)-(Vxp*ones(20,1)-old_Ft*Vref)).^2) + Cn*(abs((new_Vxn*ones(20,1)-Fb*Vref)-(Vxn*ones(20,1)-old_Fb*Vref)).^2);
    end
end
E=[E;Energy];
A
F=decimal2binary(-2048-128-8,17);
%The calibration number is -2048-128-8
B=zeros(1,16);
C=zeros(1,16);
%First row plus the third row -4096-256-16 (F1~F17)
% + Compensation Capacotor A(5) A(10) A(15)

B(16)=F(17);
C(16)=0;
[B(15),C(15)]=full_adder(F(16),0,C(16));
[B(14),C(14)]=full_adder(F(15),0,C(15));
[B(13),C(13)]=full_adder(F(14),0,C(14));
[B(12),C(12)]=full_adder(F(13),A(15),C(13));
[B(11),C(11)]=full_adder(F(12),0,C(12));
[B(10),C(10)]=full_adder(F(11),0,C(11));
[B(9),C(9)]=full_adder(F(10),0,C(10));
[B(8),C(8)]=full_adder(F(9),A(10),C(9));
[B(7),C(7)]=full_adder(F(8),0,C(8));
[B(6),C(6)]=full_adder(F(7),0,C(7));
[B(5),C(5)]=full_adder(F(6),0,C(6));
[B(4),C(4)]=full_adder(F(5),A(5),C(5));
[B(3),C(3)]=full_adder(F(4),0,C(4));
[B(2),C(2)]=full_adder(F(3),0,C(3));
[B(1),C(1)]=full_adder(F(2),0,C(2));
Bsign=full_adder(F(1),0,C(1));
%Then plus the Normal capacitor
D=zeros(1,16);
C=zeros(1,16);
[D(16),C(16)]=full_adder(B(16),A(19),0);
[D(15),C(15)]=full_adder(B(15),A(18),C(16));
[D(14),C(14)]=full_adder(B(14),A(17),C(15));
[D(13),C(13)]=full_adder(B(13),A(16),C(14));
[D(12),C(12)]=full_adder(B(12),A(14),C(13));
[D(11),C(11)]=full_adder(B(11),A(13),C(12));
[D(10),C(10)]=full_adder(B(10),A(12),C(11));
[D(9),C(9)]=full_adder(B(9),A(11),C(10));
[D(8),C(8)]=full_adder(B(8),A(9),C(9));
[D(7),C(7)]=full_adder(B(7),A(8),C(8));
[D(6),C(6)]=full_adder(B(6),A(7),C(7));
[D(5),C(5)]=full_adder(B(5),A(6),C(6));
[D(4),C(4)]=full_adder(B(4),A(4),C(5));
[D(3),C(3)]=full_adder(B(3),A(3),C(4));
[D(2),C(2)]=full_adder(B(2),A(2),C(3));
[D(1),C(1)]=full_adder(B(1),A(1),C(2));

overflow=xor(C(1),Bsign);
if overflow==1
    if D(1)==1
        D=zeros(1,16);
    else
        D=ones(1,16);
    end
end

adco=[adco;D];
end
Energy_mean=sum(E)/length(E);
