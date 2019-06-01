#!/usr/bin/env perl
use warnings;
use strict;
use feature 'state';
use Carp;
use File::Temp qw/tempfile/;
use FindBin;
use Path::Class qw/file dir/;
use IPC::Run3::Shell qw/:FATAL :run/;

=head1 SYNOPSIS

B<Tests for the F<csvmerge> script.>

=head1 AUTHOR, COPYRIGHT, AND LICENSE

Copyright (c) 2019 Hauke Daempfling (haukex@zero-g.net)
at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
Berlin, Germany, L<http://www.igb-berlin.de/>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but B<WITHOUT ANY WARRANTY>; without even the implied warranty of
B<MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE>. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

sub runit {
	my @args = @_;
	my $o = ref $args[-1] eq 'HASH' ? pop @args : {};
	state $UUT = dir($FindBin::Bin)->parent->file('csvmerge');
	my $out = run( $UUT, @args, { fail_on_stderr=>1,
		show_cmd=>Test::More->builder->output, %$o } );
	die "unepxected output: ".explain($out) if length $out;
	return 1;
}

sub tempf {
	my ($tfh,$tfn) = tempfile(UNLINK=>1);
	print $tfh @_;
	close $tfh;
	return file($tfn);
}

sub exception (&) {  ## no critic (ProhibitSubroutinePrototypes)
	return eval { shift->(); 1 } ? undef : ($@ || confess "\$@ was false");
}

use Test::More tests=>9;

{
	my $one = tempf <<'END';
"foo",bar,quz
1,2,3
4,5,6
END
	my $two = tempf <<'END';
foo,bar,quz
7,8,9
END
	my $o = tempf;
	runit('-co',$o,$one,$two);
	is_deeply scalar $o->slurp, <<'END', 'basic test';
foo,bar,quz
1,2,3
4,5,6
7,8,9
END
}

{
	my $one = tempf <<'END';
"hello","world"
111,222
END
	my $two = tempf <<'END';
hello,world
333,444
555,666
END
	runit('-ac',$one,$two);
	is_deeply scalar $one->slurp, <<'END', '--append';
"hello","world"
111,222
333,444
555,666
END
}

{
	my $one = tempf <<'END';
a,b,c
d,e,f
g,h,i
1,1,1
2,2,2
3,3,3
END
	my $two = tempf <<'END';
a,b,c
d,e,f
g,h,i
4,4,4
5,5,5
6,6,6
7,7,7
END
	my $o = tempf;
	runit('-h3','-o',$o,$one,$two);
	is_deeply scalar $o->slurp, <<'END', '--headercnt=3';
a,b,c
d,e,f
g,h,i
1,1,1
2,2,2
3,3,3
4,4,4
5,5,5
6,6,6
7,7,7
END
}

{
	my $one = tempf "foo,bar,quz\nx,y,z\n1,2,3\n";
	my $two = tempf "foo,bar,quz\nx,yy,z\n4,5,6\n";
	my $o = tempf;
	like exception { runit('-h2','-o',$o,$one,$two) },
		qr/\bheader\b.+\bdoesn't match\b/, 'header match failure';
}

{
	my $one = tempf "foo,bar,quz\n1,2\n";
	my $two = tempf "foo,bar,quz\n4,5,6\n";
	my $o = tempf;
	like exception { runit('-c','-o',$o,$one,$two) },
		qr/\bbad nr of columns\b/, 'checkcols failure';
}
{
	my $one = tempf "foo\nbar,quz\n1,2\n";
	my $two = tempf "foo\nbar,quz\n4,5,6\n";
	my $o = tempf;
	like exception { runit('-h2','-n3','-o',$o,$one,$two) },
		qr/\bbad nr of columns\b/, 'numcols failure';
}

{
	my $one = tempf <<'END';
"foo",bar,quz
1,2,3
END
	my $two = tempf <<'END';
foo,bar,quz
4,5,6
7,8
END
	my $three = tempf <<'END';
foo,bar,quz
9,10
12,13,14
END
	runit('-cfa',$one,'doesnotexist',$two,$three,
		{fail_on_stderr=>0,stderr=>\my $se});
	like $se, qr/\bdoesnotexist\b(.+\bbad nr of columns\b){2}/s, 'failsoft warns';
	is_deeply scalar $one->slurp, <<'END', 'failsoft';
"foo",bar,quz
1,2,3
4,5,6
END
}

{
	my $one = tempf <<'END';
"TOA5","Weather","CR1000X","7632","CR1000X.Std.03.02","CPU:Weather.CR1X","54860","QuarterHourlyData"
"TIMESTAMP","RECORD","BattV_Min","BattV_Avg","BattV_Max","PTemp_C_Min","PTemp_C_Avg","PTemp_C_Max","AirT_C_Min","AirT_C_Avg","AirT_C_Max","AirT_C_Std","RelHumid_Min","RelHumid","RelHumid_Max","Rain_mm_Tot","Rain_corr_mm_Tot","BP_mbar_Min","BP_mbar_Avg","BP_mbar_Max","BP_mbar_Std","WindDir_deg","WindSpd_m_s_Min","WindSpd_m_s_Avg","WindSpd_m_s_Max","WindSpd_m_s_Std","Tdewpt_C_Avg","Twetbulb_C_Avg","SunHrs_Tot","PotSlrRad_Avg","GroundT_C_Min","GroundT_C_Avg","GroundT_C_Max","GroundT_C_Std","Rad_SWin_Min","Rad_SWin_Avg","Rad_SWin_Max","Rad_SWin_Std","Rad_SWout_Min","Rad_SWout_Avg","Rad_SWout_Max","Rad_SWout_Std","Rad_LWin_Min","Rad_LWin_Avg","Rad_LWin_Max","Rad_LWin_Std","Rad_LWout_Min","Rad_LWout_Avg","Rad_LWout_Max","Rad_LWout_Std","Rad_SWnet_Min","Rad_SWnet_Avg","Rad_SWnet_Max","Rad_SWnet_Std","Rad_LWnet_Min","Rad_LWnet_Avg","Rad_LWnet_Max","Rad_LWnet_Std","Rad_SWalbedo_Min","Rad_SWalbedo_Avg","Rad_SWalbedo_Max","Rad_SWalbedo_Std","Rad_Net_Min","Rad_Net_Avg","Rad_Net_Max","Rad_Net_Std","SHF_A_Min","SHF_A_Avg","SHF_A_Max","SHF_A_Std","SHF_B_Min","SHF_B_Avg","SHF_B_Max","SHF_B_Std","VWC_C_Min","VWC_C_Avg","VWC_C_Max","VWC_C_Std","VWC_D_Min","VWC_D_Avg","VWC_D_Max","VWC_D_Std","PA_C_uS_Min","PA_C_uS_Avg","PA_C_uS_Max","PA_C_uS_Std","PA_D_uS_Min","PA_D_uS_Avg","PA_D_uS_Max","PA_D_uS_Std","WindDiag","Wind_SmplsF_Tot","Wind_Diag1F_Tot","Wind_Diag2F_Tot","Wind_Diag4F_Tot","Wind_Diag8F_Tot","Wind_Diag9F_Tot","Wind_Diag10F_Tot","Wind_NNDF_Tot","Wind_CSEF_Tot"
"TS","RN","Volts","Volts","Volts","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","%","%","%","mm","","mbar","mbar","mbar","mbar","degrees","meters/second","meters/second","meters/second","meters/second","Deg C","Deg C","hours","W/m^2","Deg C","Deg C","Deg C","Deg C","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","","","","","","","","","uSec","uSec","uSec","uSec","uSec","uSec","uSec","uSec","unitless","","","","","","","","",""
"","","Min","Avg","Max","Min","Avg","Max","Min","Avg","Max","Std","Min","Smp","Max","Tot","Tot","Min","Avg","Max","Std","Smp","Min","Avg","Max","Std","Avg","Avg","Tot","Avg","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Smp","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot"
"2019-05-23 13:30:00",0,13.58,13.61,13.61,22.08,22.2,22.3,18.31,18.46,18.54,0.057,33.94,44,46.29,0,0,512.4344,1014.103,1017.672,41.66114,288,0.14,1.2,3.03,0.58,5.153,11.47,0.203,22.69,25.27,25.31,25.36,0.028,644.2,760.2,776.2,14.37,114.2,134.9,138.3,2.614,270.5,274.4,277.8,1.316,428.4,435.1,439,2.076,533.4,625.2,641.1,12.29,-166.5,-160.7,-153.3,2.464,0.173,0.178,0.182,0.002,375.5,464.5,482.8,12.32,58.3,58.89,59.33,0.301,71.51,72.06,72.43,0.276,0.187,0.188,0.188,0,0.119,0.12,0.12,0,24.06,24.07,24.08,0.007,21.4,21.4,21.41,0.002,0,146,0,0,0,0,0,0,0,0
"2019-05-23 13:45:00",1,13.59,13.61,13.61,22.3,22.38,22.43,17.99,18.25,18.43,0.114,36.51,46.11,46.11,0,0,1017.312,1017.414,1017.571,0.058454,302,0.08,1.742,4.51,0.974,4.418,11.09,0.25,22.16,25.28,25.32,25.37,0.031,712.4,737.1,752.6,8.83,127.1,131.4,135.1,1.537,272.4,275.8,278.6,1.368,425.4,431.3,438.7,3.348,582,605.6,623.5,8.86,-165.4,-155.4,-150.1,2.854,0.17,0.178,0.183,0.003,425.8,450.2,470.7,9.83,56.16,57.34,58.29,0.603,68.86,70.34,71.5,0.781,0.186,0.187,0.187,0,0.12,0.12,0.12,0,24.03,24.04,24.06,0.01,21.4,21.41,21.41,0.002,0,180,0,0,0,0,0,0,0,0
"2019-05-23 14:00:00",2,13.59,13.61,13.61,22.43,22.45,22.46,18.01,18.33,18.62,0.157,36.08,44.28,46.65,0,0,1017.265,1017.348,1017.419,0.03236021,241,0.14,1.645,5.65,0.864,4.514,11.16,0.25,21.52,25.19,25.25,25.31,0.045,600.2,677.6,723.6,23.68,104.2,122.8,132.2,5.225,271.5,276.5,279.8,1.558,419.5,428.6,437.1,3.781,497.8,554.8,592,18.88,-162,-152.1,-145.5,3.164,0.172,0.181,0.187,0.003,348.7,402.7,437.6,17.21,52.76,54.63,56.14,0.953,65.26,67.23,68.84,1.027,0.186,0.186,0.186,0,0.12,0.12,0.12,0,24,24.01,24.03,0.01,21.41,21.41,21.42,0.002,0,180,0,0,0,0,0,0,0,0
END
	my $two = tempf <<'END';
"TOA5","Weather","CR1000X","7632","CR1000X.Std.03.02","CPU:Weather.CR1X","54860","QuarterHourlyData"
"TIMESTAMP","RECORD","BattV_Min","BattV_Avg","BattV_Max","PTemp_C_Min","PTemp_C_Avg","PTemp_C_Max","AirT_C_Min","AirT_C_Avg","AirT_C_Max","AirT_C_Std","RelHumid_Min","RelHumid","RelHumid_Max","Rain_mm_Tot","Rain_corr_mm_Tot","BP_mbar_Min","BP_mbar_Avg","BP_mbar_Max","BP_mbar_Std","WindDir_deg","WindSpd_m_s_Min","WindSpd_m_s_Avg","WindSpd_m_s_Max","WindSpd_m_s_Std","Tdewpt_C_Avg","Twetbulb_C_Avg","SunHrs_Tot","PotSlrRad_Avg","GroundT_C_Min","GroundT_C_Avg","GroundT_C_Max","GroundT_C_Std","Rad_SWin_Min","Rad_SWin_Avg","Rad_SWin_Max","Rad_SWin_Std","Rad_SWout_Min","Rad_SWout_Avg","Rad_SWout_Max","Rad_SWout_Std","Rad_LWin_Min","Rad_LWin_Avg","Rad_LWin_Max","Rad_LWin_Std","Rad_LWout_Min","Rad_LWout_Avg","Rad_LWout_Max","Rad_LWout_Std","Rad_SWnet_Min","Rad_SWnet_Avg","Rad_SWnet_Max","Rad_SWnet_Std","Rad_LWnet_Min","Rad_LWnet_Avg","Rad_LWnet_Max","Rad_LWnet_Std","Rad_SWalbedo_Min","Rad_SWalbedo_Avg","Rad_SWalbedo_Max","Rad_SWalbedo_Std","Rad_Net_Min","Rad_Net_Avg","Rad_Net_Max","Rad_Net_Std","SHF_A_Min","SHF_A_Avg","SHF_A_Max","SHF_A_Std","SHF_B_Min","SHF_B_Avg","SHF_B_Max","SHF_B_Std","VWC_C_Min","VWC_C_Avg","VWC_C_Max","VWC_C_Std","VWC_D_Min","VWC_D_Avg","VWC_D_Max","VWC_D_Std","PA_C_uS_Min","PA_C_uS_Avg","PA_C_uS_Max","PA_C_uS_Std","PA_D_uS_Min","PA_D_uS_Avg","PA_D_uS_Max","PA_D_uS_Std","WindDiag","Wind_SmplsF_Tot","Wind_Diag1F_Tot","Wind_Diag2F_Tot","Wind_Diag4F_Tot","Wind_Diag8F_Tot","Wind_Diag9F_Tot","Wind_Diag10F_Tot","Wind_NNDF_Tot","Wind_CSEF_Tot"
"TS","RN","Volts","Volts","Volts","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","%","%","%","mm","","mbar","mbar","mbar","mbar","degrees","meters/second","meters/second","meters/second","meters/second","Deg C","Deg C","hours","W/m^2","Deg C","Deg C","Deg C","Deg C","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","","","","","","","","","uSec","uSec","uSec","uSec","uSec","uSec","uSec","uSec","unitless","","","","","","","","",""
"","","Min","Avg","Max","Min","Avg","Max","Min","Avg","Max","Std","Min","Smp","Max","Tot","Tot","Min","Avg","Max","Std","Smp","Min","Avg","Max","Std","Avg","Avg","Tot","Avg","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Smp","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot"
"2019-05-23 14:15:00",3,13.58,13.61,13.61,22.44,22.44,22.45,18.33,18.51,18.76,0.106,36.51,41.53,49.72,0,0,1017.184,1017.25,1017.339,0.02678544,342,0.11,1.61,4.58,0.832,4.785,11.35,0.25,20.81,25.17,25.2,25.22,0.014,656,674.4,687,7.701,121,124.4,127.3,1.556,273.8,278,280.9,1.324,423.7,429.6,434.6,2.605,534.5,550,561.8,6.78,-157.7,-151.6,-146.1,2.472,0.181,0.185,0.188,0.002,381.5,398.3,412.3,6.511,47.88,50.24,52.73,1.41,61.48,63.23,65.23,1.09,0.185,0.185,0.186,0,0.12,0.12,0.12,0,23.96,23.98,24,0.009,21.41,21.42,21.42,0.002,0,180,0,0,0,0,0,0,0,0
END
	my $three = tempf <<'END';
"TOA5","Weather","CR1000X","7632","CR1000X.Std.03.02","CPU:Weather.CR1X","54860","QuarterHourlyData"
"TIMESTAMP","RECORD","BattV_Min","BattV_Avg","BattV_Max","PTemp_C_Min","PTemp_C_Avg","PTemp_C_Max","AirT_C_Min","AirT_C_Avg","AirT_C_Max","AirT_C_Std","RelHumid_Min","RelHumid","RelHumid_Max","Rain_mm_Tot","Rain_corr_mm_Tot","BP_mbar_Min","BP_mbar_Avg","BP_mbar_Max","BP_mbar_Std","WindDir_deg","WindSpd_m_s_Min","WindSpd_m_s_Avg","WindSpd_m_s_Max","WindSpd_m_s_Std","Tdewpt_C_Avg","Twetbulb_C_Avg","SunHrs_Tot","PotSlrRad_Avg","GroundT_C_Min","GroundT_C_Avg","GroundT_C_Max","GroundT_C_Std","Rad_SWin_Min","Rad_SWin_Avg","Rad_SWin_Max","Rad_SWin_Std","Rad_SWout_Min","Rad_SWout_Avg","Rad_SWout_Max","Rad_SWout_Std","Rad_LWin_Min","Rad_LWin_Avg","Rad_LWin_Max","Rad_LWin_Std","Rad_LWout_Min","Rad_LWout_Avg","Rad_LWout_Max","Rad_LWout_Std","Rad_SWnet_Min","Rad_SWnet_Avg","Rad_SWnet_Max","Rad_SWnet_Std","Rad_LWnet_Min","Rad_LWnet_Avg","Rad_LWnet_Max","Rad_LWnet_Std","Rad_SWalbedo_Min","Rad_SWalbedo_Avg","Rad_SWalbedo_Max","Rad_SWalbedo_Std","Rad_Net_Min","Rad_Net_Avg","Rad_Net_Max","Rad_Net_Std","SHF_A_Min","SHF_A_Avg","SHF_A_Max","SHF_A_Std","SHF_B_Min","SHF_B_Avg","SHF_B_Max","SHF_B_Std","VWC_C_Min","VWC_C_Avg","VWC_C_Max","VWC_C_Std","VWC_D_Min","VWC_D_Avg","VWC_D_Max","VWC_D_Std","PA_C_uS_Min","PA_C_uS_Avg","PA_C_uS_Max","PA_C_uS_Std","PA_D_uS_Min","PA_D_uS_Avg","PA_D_uS_Max","PA_D_uS_Std","WindDiag","Wind_SmplsF_Tot","Wind_Diag1F_Tot","Wind_Diag2F_Tot","Wind_Diag4F_Tot","Wind_Diag8F_Tot","Wind_Diag9F_Tot","Wind_Diag10F_Tot","Wind_NNDF_Tot","Wind_CSEF_Tot"
"TS","RN","Volts","Volts","Volts","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","%","%","%","mm","","mbar","mbar","mbar","mbar","degrees","meters/second","meters/second","meters/second","meters/second","Deg C","Deg C","hours","W/m^2","Deg C","Deg C","Deg C","Deg C","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","","","","","","","","","uSec","uSec","uSec","uSec","uSec","uSec","uSec","uSec","unitless","","","","","","","","",""
"","","Min","Avg","Max","Min","Avg","Max","Min","Avg","Max","Std","Min","Smp","Max","Tot","Tot","Min","Avg","Max","Std","Smp","Min","Avg","Max","Std","Avg","Avg","Tot","Avg","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Smp","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot"
"2019-05-23 14:30:00",4,13.56,13.59,13.61,22.45,22.46,22.47,18.15,18.39,18.72,0.138,36.78,43.89,47.73,0,0,1017.156,1017.216,1017.318,0.02804078,341,0.2,1.83,4.27,0.781,4.627,11.23,0.25,20.05,25.09,25.11,25.17,0.023,604.1,663.4,691.9,14.96,113.2,124,130.8,3.012,277.7,280.9,284.9,1.586,425.4,429,433.5,2.001,490.1,539.4,563.6,12.26,-151.9,-148,-143.9,1.52,0.182,0.187,0.191,0.002,341.3,391.4,416.9,12.28,43.53,45.67,47.85,1.262,58.55,59.95,61.47,0.86,0.184,0.184,0.185,0,0.12,0.12,0.12,0,23.93,23.95,23.96,0.01,21.42,21.42,21.43,0.002,0,180,0,0,0,0,0,0,0,0
END
	my $four = tempf <<'END';
"TOA5","Weather","CR1000X","7632","CR1000X.Std.03.02","CPU:Weather.CR1X","54860","QuarterHourlyData"
"TIMESTAMP","RECORD","BattV_Min","BattV_Avg","BattV_Max","PTemp_C_Min","PTemp_C_Avg","PTemp_C_Max","AirT_C_Min","AirT_C_Avg","AirT_C_Max","AirT_C_Std","RelHumid_Min","RelHumid","RelHumid_Max","Rain_mm_Tot","Rain_corr_mm_Tot","BP_mbar_Min","BP_mbar_Avg","BP_mbar_Max","BP_mbar_Std","WindDir_deg","WindSpd_m_s_Min","WindSpd_m_s_Avg","WindSpd_m_s_Max","WindSpd_m_s_Std","Tdewpt_C_Avg","Twetbulb_C_Avg","SunHrs_Tot","PotSlrRad_Avg","GroundT_C_Min","GroundT_C_Avg","GroundT_C_Max","GroundT_C_Std","Rad_SWin_Min","Rad_SWin_Avg","Rad_SWin_Max","Rad_SWin_Std","Rad_SWout_Min","Rad_SWout_Avg","Rad_SWout_Max","Rad_SWout_Std","Rad_LWin_Min","Rad_LWin_Avg","Rad_LWin_Max","Rad_LWin_Std","Rad_LWout_Min","Rad_LWout_Avg","Rad_LWout_Max","Rad_LWout_Std","Rad_SWnet_Min","Rad_SWnet_Avg","Rad_SWnet_Max","Rad_SWnet_Std","Rad_LWnet_Min","Rad_LWnet_Avg","Rad_LWnet_Max","Rad_LWnet_Std","Rad_SWalbedo_Min","Rad_SWalbedo_Avg","Rad_SWalbedo_Max","Rad_SWalbedo_Std","Rad_Net_Min","Rad_Net_Avg","Rad_Net_Max","Rad_Net_Std","SHF_A_Min","SHF_A_Avg","SHF_A_Max","SHF_A_Std","SHF_B_Min","SHF_B_Avg","SHF_B_Max","SHF_B_Std","VWC_C_Min","VWC_C_Avg","VWC_C_Max","VWC_C_Std","VWC_D_Min","VWC_D_Avg","VWC_D_Max","VWC_D_Std","PA_C_uS_Min","PA_C_uS_Avg","PA_C_uS_Max","PA_C_uS_Std","PA_D_uS_Min","PA_D_uS_Avg","PA_D_uS_Max","PA_D_uS_Std","WindDiag","Wind_SmplsF_Tot","Wind_Diag1F_Tot","Wind_Diag2F_Tot","Wind_Diag4F_Tot","Wind_Diag8F_Tot","Wind_Diag9F_Tot","Wind_Diag10F_Tot","Wind_NNDF_Tot","Wind_CSEF_Tot"
"TS","RN","Volts","Volts","Volts","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","%","%","%","mm","","mbar","mbar","mbar","mbar","degrees","meters/second","meters/second","meters/second","meters/second","Deg C","Deg C","hours","W/m^2","Deg C","Deg C","Deg C","Deg C","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","","","","","","","","","uSec","uSec","uSec","uSec","uSec","uSec","uSec","uSec","unitless","","","","","","","","",""
"","","Min","Avg","Max","Min","Avg","Max","Min","Avg","Max","Std","Min","Smp","Max","Tot","Tot","Min","Avg","Max","Std","Smp","Min","Avg","Max","Std","Avg","Avg","Tot","Avg","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Smp","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot"
"2019-05-23 14:45:00",5,13.56,13.58,13.58,22.47,22.52,22.58,18.18,18.58,19.04,0.237,37.93,38.74,50.62,0,0,1017.075,1017.153,1017.245,0.04158114,293,0.04,1.502,4.93,0.864,5.474,11.64,0.25,19.25,24.98,25.08,25.12,0.038,565.1,629.3,668.3,31.1,105.4,118.9,127.7,6.241,279.1,284.3,287.8,1.552,422.1,428.6,437.6,3.928,459.6,510.3,540.7,25,-156.7,-144.2,-137.2,4.228,0.183,0.189,0.193,0.002,320.2,366.2,395.9,22.1,40.41,41.86,43.51,0.886,56.49,57.52,58.53,0.573,0.183,0.183,0.184,0,0.12,0.12,0.12,0,23.9,23.91,23.93,0.009,21.42,21.43,21.43,0.002,0,180,0,0,0,0,0,0,0,0
"2019-05-23 15:00:00",6,13.56,13.58,13.58,22.58,22.62,22.68,18.23,18.73,19.17,0.286,38.5,45.01,51.89,0,0,1017.068,1017.147,1017.245,0.03555314,215,0.06,1,3.8,0.654,6.121,11.97,0.25,18.42,24.85,24.89,24.98,0.036,518.1,611.4,639.6,22.46,99.2,117.9,124.5,4.315,281,286,288.4,1.242,424.2,429.4,434.9,2.739,417.7,493.4,516.4,18.36,-149.2,-143.4,-138.2,2.679,0.186,0.193,0.196,0.002,274,350.1,374.7,19.1,37.31,38.83,40.39,0.901,52.56,54.65,56.48,1.176,0.182,0.182,0.183,0,0.12,0.12,0.12,0,23.87,23.88,23.9,0.008,21.43,21.43,21.43,0.002,0,180,0,0,0,0,0,0,0,0
END
	runit('-n100','-ah4',$one,$two,$three,$four);
	is_deeply scalar $one->slurp, <<'END', 'real-world data';
"TOA5","Weather","CR1000X","7632","CR1000X.Std.03.02","CPU:Weather.CR1X","54860","QuarterHourlyData"
"TIMESTAMP","RECORD","BattV_Min","BattV_Avg","BattV_Max","PTemp_C_Min","PTemp_C_Avg","PTemp_C_Max","AirT_C_Min","AirT_C_Avg","AirT_C_Max","AirT_C_Std","RelHumid_Min","RelHumid","RelHumid_Max","Rain_mm_Tot","Rain_corr_mm_Tot","BP_mbar_Min","BP_mbar_Avg","BP_mbar_Max","BP_mbar_Std","WindDir_deg","WindSpd_m_s_Min","WindSpd_m_s_Avg","WindSpd_m_s_Max","WindSpd_m_s_Std","Tdewpt_C_Avg","Twetbulb_C_Avg","SunHrs_Tot","PotSlrRad_Avg","GroundT_C_Min","GroundT_C_Avg","GroundT_C_Max","GroundT_C_Std","Rad_SWin_Min","Rad_SWin_Avg","Rad_SWin_Max","Rad_SWin_Std","Rad_SWout_Min","Rad_SWout_Avg","Rad_SWout_Max","Rad_SWout_Std","Rad_LWin_Min","Rad_LWin_Avg","Rad_LWin_Max","Rad_LWin_Std","Rad_LWout_Min","Rad_LWout_Avg","Rad_LWout_Max","Rad_LWout_Std","Rad_SWnet_Min","Rad_SWnet_Avg","Rad_SWnet_Max","Rad_SWnet_Std","Rad_LWnet_Min","Rad_LWnet_Avg","Rad_LWnet_Max","Rad_LWnet_Std","Rad_SWalbedo_Min","Rad_SWalbedo_Avg","Rad_SWalbedo_Max","Rad_SWalbedo_Std","Rad_Net_Min","Rad_Net_Avg","Rad_Net_Max","Rad_Net_Std","SHF_A_Min","SHF_A_Avg","SHF_A_Max","SHF_A_Std","SHF_B_Min","SHF_B_Avg","SHF_B_Max","SHF_B_Std","VWC_C_Min","VWC_C_Avg","VWC_C_Max","VWC_C_Std","VWC_D_Min","VWC_D_Avg","VWC_D_Max","VWC_D_Std","PA_C_uS_Min","PA_C_uS_Avg","PA_C_uS_Max","PA_C_uS_Std","PA_D_uS_Min","PA_D_uS_Avg","PA_D_uS_Max","PA_D_uS_Std","WindDiag","Wind_SmplsF_Tot","Wind_Diag1F_Tot","Wind_Diag2F_Tot","Wind_Diag4F_Tot","Wind_Diag8F_Tot","Wind_Diag9F_Tot","Wind_Diag10F_Tot","Wind_NNDF_Tot","Wind_CSEF_Tot"
"TS","RN","Volts","Volts","Volts","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","Deg C","%","%","%","mm","","mbar","mbar","mbar","mbar","degrees","meters/second","meters/second","meters/second","meters/second","Deg C","Deg C","hours","W/m^2","Deg C","Deg C","Deg C","Deg C","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","W/m^2","","","","","","","","","uSec","uSec","uSec","uSec","uSec","uSec","uSec","uSec","unitless","","","","","","","","",""
"","","Min","Avg","Max","Min","Avg","Max","Min","Avg","Max","Std","Min","Smp","Max","Tot","Tot","Min","Avg","Max","Std","Smp","Min","Avg","Max","Std","Avg","Avg","Tot","Avg","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Min","Avg","Max","Std","Smp","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot","Tot"
"2019-05-23 13:30:00",0,13.58,13.61,13.61,22.08,22.2,22.3,18.31,18.46,18.54,0.057,33.94,44,46.29,0,0,512.4344,1014.103,1017.672,41.66114,288,0.14,1.2,3.03,0.58,5.153,11.47,0.203,22.69,25.27,25.31,25.36,0.028,644.2,760.2,776.2,14.37,114.2,134.9,138.3,2.614,270.5,274.4,277.8,1.316,428.4,435.1,439,2.076,533.4,625.2,641.1,12.29,-166.5,-160.7,-153.3,2.464,0.173,0.178,0.182,0.002,375.5,464.5,482.8,12.32,58.3,58.89,59.33,0.301,71.51,72.06,72.43,0.276,0.187,0.188,0.188,0,0.119,0.12,0.12,0,24.06,24.07,24.08,0.007,21.4,21.4,21.41,0.002,0,146,0,0,0,0,0,0,0,0
"2019-05-23 13:45:00",1,13.59,13.61,13.61,22.3,22.38,22.43,17.99,18.25,18.43,0.114,36.51,46.11,46.11,0,0,1017.312,1017.414,1017.571,0.058454,302,0.08,1.742,4.51,0.974,4.418,11.09,0.25,22.16,25.28,25.32,25.37,0.031,712.4,737.1,752.6,8.83,127.1,131.4,135.1,1.537,272.4,275.8,278.6,1.368,425.4,431.3,438.7,3.348,582,605.6,623.5,8.86,-165.4,-155.4,-150.1,2.854,0.17,0.178,0.183,0.003,425.8,450.2,470.7,9.83,56.16,57.34,58.29,0.603,68.86,70.34,71.5,0.781,0.186,0.187,0.187,0,0.12,0.12,0.12,0,24.03,24.04,24.06,0.01,21.4,21.41,21.41,0.002,0,180,0,0,0,0,0,0,0,0
"2019-05-23 14:00:00",2,13.59,13.61,13.61,22.43,22.45,22.46,18.01,18.33,18.62,0.157,36.08,44.28,46.65,0,0,1017.265,1017.348,1017.419,0.03236021,241,0.14,1.645,5.65,0.864,4.514,11.16,0.25,21.52,25.19,25.25,25.31,0.045,600.2,677.6,723.6,23.68,104.2,122.8,132.2,5.225,271.5,276.5,279.8,1.558,419.5,428.6,437.1,3.781,497.8,554.8,592,18.88,-162,-152.1,-145.5,3.164,0.172,0.181,0.187,0.003,348.7,402.7,437.6,17.21,52.76,54.63,56.14,0.953,65.26,67.23,68.84,1.027,0.186,0.186,0.186,0,0.12,0.12,0.12,0,24,24.01,24.03,0.01,21.41,21.41,21.42,0.002,0,180,0,0,0,0,0,0,0,0
"2019-05-23 14:15:00",3,13.58,13.61,13.61,22.44,22.44,22.45,18.33,18.51,18.76,0.106,36.51,41.53,49.72,0,0,1017.184,1017.25,1017.339,0.02678544,342,0.11,1.61,4.58,0.832,4.785,11.35,0.25,20.81,25.17,25.2,25.22,0.014,656,674.4,687,7.701,121,124.4,127.3,1.556,273.8,278,280.9,1.324,423.7,429.6,434.6,2.605,534.5,550,561.8,6.78,-157.7,-151.6,-146.1,2.472,0.181,0.185,0.188,0.002,381.5,398.3,412.3,6.511,47.88,50.24,52.73,1.41,61.48,63.23,65.23,1.09,0.185,0.185,0.186,0,0.12,0.12,0.12,0,23.96,23.98,24,0.009,21.41,21.42,21.42,0.002,0,180,0,0,0,0,0,0,0,0
"2019-05-23 14:30:00",4,13.56,13.59,13.61,22.45,22.46,22.47,18.15,18.39,18.72,0.138,36.78,43.89,47.73,0,0,1017.156,1017.216,1017.318,0.02804078,341,0.2,1.83,4.27,0.781,4.627,11.23,0.25,20.05,25.09,25.11,25.17,0.023,604.1,663.4,691.9,14.96,113.2,124,130.8,3.012,277.7,280.9,284.9,1.586,425.4,429,433.5,2.001,490.1,539.4,563.6,12.26,-151.9,-148,-143.9,1.52,0.182,0.187,0.191,0.002,341.3,391.4,416.9,12.28,43.53,45.67,47.85,1.262,58.55,59.95,61.47,0.86,0.184,0.184,0.185,0,0.12,0.12,0.12,0,23.93,23.95,23.96,0.01,21.42,21.42,21.43,0.002,0,180,0,0,0,0,0,0,0,0
"2019-05-23 14:45:00",5,13.56,13.58,13.58,22.47,22.52,22.58,18.18,18.58,19.04,0.237,37.93,38.74,50.62,0,0,1017.075,1017.153,1017.245,0.04158114,293,0.04,1.502,4.93,0.864,5.474,11.64,0.25,19.25,24.98,25.08,25.12,0.038,565.1,629.3,668.3,31.1,105.4,118.9,127.7,6.241,279.1,284.3,287.8,1.552,422.1,428.6,437.6,3.928,459.6,510.3,540.7,25,-156.7,-144.2,-137.2,4.228,0.183,0.189,0.193,0.002,320.2,366.2,395.9,22.1,40.41,41.86,43.51,0.886,56.49,57.52,58.53,0.573,0.183,0.183,0.184,0,0.12,0.12,0.12,0,23.9,23.91,23.93,0.009,21.42,21.43,21.43,0.002,0,180,0,0,0,0,0,0,0,0
"2019-05-23 15:00:00",6,13.56,13.58,13.58,22.58,22.62,22.68,18.23,18.73,19.17,0.286,38.5,45.01,51.89,0,0,1017.068,1017.147,1017.245,0.03555314,215,0.06,1,3.8,0.654,6.121,11.97,0.25,18.42,24.85,24.89,24.98,0.036,518.1,611.4,639.6,22.46,99.2,117.9,124.5,4.315,281,286,288.4,1.242,424.2,429.4,434.9,2.739,417.7,493.4,516.4,18.36,-149.2,-143.4,-138.2,2.679,0.186,0.193,0.196,0.002,274,350.1,374.7,19.1,37.31,38.83,40.39,0.901,52.56,54.65,56.48,1.176,0.182,0.182,0.183,0,0.12,0.12,0.12,0,23.87,23.88,23.9,0.008,21.43,21.43,21.43,0.002,0,180,0,0,0,0,0,0,0,0
END
}

