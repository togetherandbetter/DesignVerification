#!usr/bin/perl

##
##---------------------------------------------------------------------------------------------------
##generate uvm tb, basically including 5 level structure. top/test/env/agent/seq/seqr/driver/monitor/interface, scb/refm/cov/asseration/seqlib
##project
##       +rtl
##       +doc
##       +verif
##             +tb
##             +env
##             +agent
##             +tests
##                   +seqlib
##             +sim
##                   +scripts
##Author:togather_and_better
##this script is based on an open uvm gen.pl and do some modify to keep file and dir simple
##this scripts support several input agent , output agent, agent with ral, for the ral agent, support adapter for i2c/spi/apb/ahb,not support yet.
##any issue/suggestion, please contact ic_v@qq.com
##-----------------------------------------------------------------------------------------------------

use strict;
use warnings;
require 5.8.0;

use File::Copy "cp";
use File::stat;
use File::Path;


##user define information
#--------------------------------------please modify it before run this script---------------------------
my $Copyright = "Copyright (C) 2018 by ...Ltd";
my $name = " ";
my $email="";
my $dept = "RD";
my $version="V1";
#--------------------------------------------------------------------------------------------------------


my @in_agent_list=();
my @out_agent_list=();
my @ral_agent_list=();
my @agent_list;
my @agent_var_array;
my $project_name="";
my $regmodel_name="";
my $argnum;
my $continue_on_warning;
my $regmodel=0;
my $dir;
my $template_name;
my $agent_name;
my $agent_if;
my $ele;
my $timeunit     = "1ns";
my $timeprecision= "1ps";

open(LOGFILE,">uvm_tb_gen.log");
parse_cmdline();

if(-e $project_name){
	print "--------------------------------\n      ERROR,Existing project files $project_name.please double check it , EXIT !!!\n";
	print "--------------------------------\n";
	exit;
}

mkdir($project_name,0755);
$dir = $project_name . "/rtl";
mkdir($dir,0755);
$dir = $project_name . "/doc";
mkdir($dir,0755);
$dir = $project_name . "/verif";
mkdir($dir,0755);
$dir = $project_name . "/verif/tb";
mkdir($dir,0755);
$dir = $project_name . "/verif/env";
mkdir($dir,0755);
$dir = $project_name . "/verif/agent";
mkdir($dir,0755);
$dir = $project_name . "/verif/tests";
mkdir($dir,0755);
$dir = $project_name . "/verif/sim";
mkdir($dir,0755);
$dir = $project_name . "/verif/sim/scripts";
mkdir($dir,0755);
$dir = $project_name . "/verif/tests/seqlib";
mkdir($dir,0755);
#$dir = $project_name . "/verif/reg_model";
#mkdir($dir,0755);
#$dir = $project_name . "/verif/env/refm";
#mkdir($dir,0755);
$dir = $project_name . "/verif/env/reg_model";
mkdir($dir,0755);







my $project = $project_name;
my $agent_item;
&template_gen("act",@in_agent_list);
&template_gen("pas",@out_agent_list);
&template_gen("act",@ral_agent_list);
push@agent_list,@in_agent_list;
push@agent_list,@out_agent_list;
push@agent_list,@ral_agent_list;

print LOGFILE "top env agents \n";
print "generating testbench\n";
print LOGFILE "generating testbench\n";
my $tbname = $project_name;
my $envname = $project_name . "_env";

gen_refm();
gen_scb();
gen_top_config();
gen_top_env();


gen_top_pkg();
gen_top_test();
gen_top();

print "writing simulator script to ${project}/sim directory\n";
print LOGFILE "writing simulator script to ${project}/sim directory\n";


gen_vcs_script();


print "Code Generation complete\n";
print LOGFILE "Code Generation complete\n";

sub template_gen{
	my ($template_type,@list) = @_;
	print "\n Parsing Input Agent ...\n\n";
	print LOGFILE "\n Parsing Input Agent ..\n\n";
	foreach my $i(0 .. @list - 1){
		if($list[$i] ne ""){
			$template_name = $list[$i];
			printf "Reading[$i]:$list[$i]\n";
			printf LOGFILE "Reading[$i]:$list[$i]\n";
			#make the directories
			$agent_name = $template_name;
			$agent_if   = "${agent_name}_if";
			$agent_item = "${agent_name}_seq_item";
			
			$dir = $project . "/verif/agent/" . $agent_name;
			printf LOGFILE "dir :$dir\n";
			mkdir ($dir, 0755);
			
			
			
			print "Writing code to files\n";
			print LOGFILE "Writing code to files\n";
			
			#create the agent files
			gen_if();
			gen_seq_item();
			gen_config($template_type);
			if($template_type eq "act"){
				gen_driver();
				gen_seq();
				gen_sequencer();
			}
			gen_monitor();
			
			gen_agent($template_type);
			
			
			
			
			
			
			
			#generate agent_pkg file
			gen_agent_pkg($template_type);
			
		}
	}
}#end sub

sub usage{
	print #"******USAGE:perl uvm_tb_gen.pl -help/h (print this message)\n";
	print #"\n";
	print #"this scritps support several input agent, output agent, agent with ral\n";
	print #"any suggestion, please contact ic_v\@qq.com\n";
	print #
	"perl uvm_tb_gen.pl -p project name -i list (input agent name)/active -o list (output agent name)/passive -r register agent with ral\n\n";
	print #"example 1: one input agent, one output agent, one ral agent:\n perl uvm_tb_gen.pl -p uart -i uart -o spi -r apb\n";
	print #"example 2: two input agent:\n	perl uvm_tb_gen.pl -p uart -i uart localbus";
	print #"example 3: two input agent, one output agent, two ral agent:\n	perl uvm_tb_gen.pl -p uart -i uart localbus -o spi -r apb ahb\n\n";
	print #"***********************************************************\n";
	exit;#
}#end sub usage

sub parse_cmdline{
	print LOGFILE "\n Parsing cmdline ...\n\n";
	print LOGFILE "num args is " . $#ARGV ."\n";
	if($#ARGV == -1){usage();}  ###no arguments ,print help and exit
	if($ARGV[0] =~ m/\s*(-help|-hel|-he|-h)/i){
		usage();
	}
	my $i;
	my $pnum0 = -1;
	my $pnum1 = -1;
	my $pnum2 = -1;
	my $in_agent_st = -1;
	my $out_agent_st= -1;
	$continue_on_warning = 0;
	
	#Searching for "continue_on critical warnings" flag
	foreach $argnum(0 .. $#ARGV){
		if($ARGV[$argnum =~ m/\s*(-c)/i]){
			$pnum0   = $argnum;
			$continue_on_warning = 1;
			printf LOGFILE
				"Code generation will continue if critical warning are issued\n";
		}
		
	}
	
	#Searching for register flag
	printf LOGFILE "Searching for regmodel flag\n";
	foreach $argnum(0..$#ARGV){
		if($ARGV[$argnum] =~ m/\s*(-r)/i){
			$regmodel = 1;
			$pnum1 = $argnum;
			foreach $i(($pnum1+1) .. $#ARGV){
				push @ral_agent_list,$ARGV[$i];
				printf LOGFILE "regmodel: $ARGV[$i],Register layer will be include\n";
				printf LOGFILE "pnum1:$pnum1\n";
			}
		}
		
	}
	
	#Searching for project_name
	printf LOGFILE "Searching for tb_name\n";
	foreach $argnum(0 .. $#ARGV){
		if($ARGV[$argnum] =~ m/\s*(-p)/i){
			$project_name = $ARGV[$argnum +1];
			$pnum2 =$argnum;
			printf LOGFILE "tb_name:$project_name\n";
			printf LOGFILE "pnum2:$pnum2\n";
		}
	}
	$project_name or die "ERROR! You must specify the top_level mudel name using the switch -p \n";
	
	
	#Searching for agent names
	printf LOGFILE "Searching for input agents \n";
	foreach $argnum(0..$#ARGV){
		if($ARGV[$argnum] =~ m/\s*(-i)/i){
		
			$in_agent_st = $argnum +1;
			
			
			foreach $i($in_agent_st..$#ARGV){
				if($ARGV[$i] =~ /-/){ last;
				}else{
					push @in_agent_list,$ARGV[$i];
					printf LOGFILE "input agent:$ARGV[$i] will be include\n";
					printf LOGFILE "in_agent_st:$in_agent_st\n"; 					
				}
			}
		}
	}
	
	
	#Searching for agent names
	printf LOGFILE "Searching for output agents\n";
	foreach $argnum(0..$#ARGV){
		if($ARGV[$argnum] =~ m/\s*(-o)/i){
			
			$out_agent_st = $argnum +1;
			
			
			foreach $i($out_agent_st..$#ARGV){
				if($ARGV[$i] =~ /-/){ last;
				}else{
					push @out_agent_list,$ARGV[$i];
					printf LOGFILE "output agent :$ARGV[$i] will be include";
					printf LOGFILE "out_agent_st :$out_agent_st\n";
				}
			}
		}
	}
	
}#end sub parse_cmdline


sub pretty_print{

#
#

	my ($arg1ref,$arg2ref,$arg3ref)=@_;
	my @string1 = @{$arg1ref};
	my @string2 = @{$arg2ref};
	my @string3 = @{$arg3ref};
	my $string1_len = @string1;
	my $string2_len = @string2;
	my $string3_len = @string3;
	my $i;
	unless($string1_len == $string2_len and ($string3_len == $string2_len or $string3_len ==0)){
		die"parameters to pretty_print are wrong";
	}
	
	my $maxlen1 =0;
	for ($i = 0; $i < @string1; $i++){
		if( length( $string2[$i] ) > 0){
			my $txt = $string1[$i];
			if(length($txt) > $maxlen1){$maxlen1 = length($txt);}
		}
	}
	
	my $maxlen2 =0;
	foreach $ele(@string2){
		if(length($ele) > $maxlen2){
		$maxlen2 = length($ele);
		}
	}	
	for($i = 0; $i < @string1; $i++){
		my $txt = $string1[$i];
		print FH $txt;
		if(length($string2[$i])>0){
			for(1 .. $maxlen1 - length($txt)){print FH "";}
			$txt = $string2[$i];
			print FH $txt;
			if($string3_len>0){
				for(1..$maxlen2-length($txt)){print FH "";}
				print FH $string3[$i];
			}
			print FH "\n";
		}
	}
}

sub write_file_header{
	my ($fname,$descript)=@_;
	print FH
"=============================================================\n";
	print FH "// $Copyright\n";
	print FH
"=============================================================\n";
	print FH "//Project : ".$project . "\n";
	print FH "//\n";
	print FH "//File Name : $fname\n";
	print FH "//\n";
	print FH "//Author : Name :$name\n";
	print FH "//         Ename:$email\n";
	print FH "//         Dept :$dept\n";
	print FH "//\n";
	print FH "//Version : $version\n";
	print FH
"=============================================================\n";
	print FH "//Description:\n";
	print FH "//\n";
	print FH "//$descript\n";
	print FH "//\n";
	print FH
"=============================================================\n";
}

sub gen_if{
	$dir = $project . "/verif/agent/" . $agent_name;
	open (FH,">" . $dir . "/" . $agent_name . "_if.sv")
		||die("Exiting due to Error:can't open interface:$agent_name");
	
	write_file_header "${agent_name}_if.sv","Signal interface for agent $agent_name";
	
	print FH "`inndef ".uc($agent_name)."_IF_SV\n";
	print FH "`define " .uc($agent_name)."_IF_SV\n";
	print FH "interface " . $agent_if . "(); \n";
	print FH "\n";
	print FH "\n";
	print FH "\n";
	
	
	
	
	print FH "// You could add properties and asseration , for example\n";
	print FH "//property name;\n";
	print FH "//...\n";
	print FH "//endproperty:name\n";
	print FH "//label:assert property();\n";
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	print FH "endinterface : " . $agent_if ."\n\n";
	print FH "`endif//".uc($agent_name)."_IF_SV\n\n";
	close(FH);	
}


sub gen_seq_item{
	printf LOGFILE "AGRNT_ITEM:$agent_item\n";
	$dir = $project."/verif/agent/".$agent_name;
	open(FH,">" . $dir."/".$agent_item.".sv")
		||die("Exiting due to Error:can't open data_item:$agent_item");
		
	write_file_header"${agent_item}.sv","Sequence item for ${agent_name}_sequencer";
	
	print FH "`ifndef " . uc($agent_item)."_SV\n";
	print FH "`define " . uc($agent_item)."_SV\n\n";
	
	
	
	print FH "class ${agent_item} extends uvm_sequence_item;\n";
	print FH "\n";
	print FH "	`uvm_object_utils(".$agent_item.")\n";
	print FH "\n";
	
	foreach my $var_decl(@agent_var_array){
		print FH "$var_decl\n";
	}
	print FH "\n";
	
	
	
	
	
	
	
	
	
	print FH "	extern function new (string name = \"$agent_item\");\n";
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	print FH "endclass:$agent_item\n";
	print FH "\n\n";
	print FH "function ${agent_item}::new(string name =\"$agent_item\");\n";
	print FH "	super.new(name);\n";
	print FH "endfunction : new\n";
	print FH "\n\n";
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	print FH "`endif//".uc($agent_item)."_SV\n\n";

	close(FH);
}

sub gen_config{
	my ($template_type) = @_;
	print "type = $template_type,	agent name = $agent_name\n";
	$dir = $project . "/verif/agent/" . $agent_name;
	open (FH, ">" . $dir ."/" . $agent_name . "_agent_config.sv")
		||die ("Exiting due to Error: can't open config: $agent_name");
	write_file_header"${agent_name}_agent_config.sv","Cofiguration for agent $agent_name";

	print FH "`ifndef ".uc($agent_name)."_AGENT_CONFIG_SV\n";
	print FH "`define ".uc($agent_name)."_AGENT_CONFIG_SV\n\n";

	print FH "class ${agent_name}_agent_config extends uvm_object;\n";
	print FH "\n";

	print FH "`uvm_object_utils(${agent_name}_agent_config)\n";
	print FH "\n";
	if($template_type eq "pas"){
		print FH "	rand uvm_active_passive_enum is_active = UVM_PASSIVE;\n";
	}else{
		print FH "	rand uvm_active_passive_enum is_active = UVM_ACTIVE;\n";
	}
	print FH "rand bit coverage_enable = 0;\n";
	print FH "rand bit check_enable = 0;\n";































	print FH "\n";

	print FH "	extern function new (string name =\"$agent_name\_agent_config\");\n";
	print FH "\n";

	print FH "endclass : " . $agent_name . "_agent_config \n";
	print FH "\n\n";
	print FH "function ${agent_name}_agent_config::new(string name = \"$agent_name\_agent_config\");\n";
	print FH "	super.new(name);\n";
	print FH "endfunction ：new\n";
	print FH "\n\n";

	print FH "`endif // ".uc($agent_name) . "_AGENT_CONFIG_SV\n\n";
	close(FH);
}

sub gen_driver{
	$dir = $project . "/verif/agent/" . $agent_name;
	open (FH, ">" . $dir . "/" . $agent_name . "_driver.sv")
		||die("Exiting due to Error: can't open driver: $agent_name");

	write_file_header"${agent_name}_driver.sv","Driver foor $agent_name";
	
	print FH "`ifndef " . uc($agent_name) . "_DRIVER_SV\n";
	print FH "`define " . uc($agent_name) . "_DRIVER_SV\n\n";

	print FH "class ${agent_name}_driver extends uvm_driver #(${agent_item});\n";
	print FH "\n";
	print FH "	`uvm_component_utils(". $agent_name . "_driver)\n";
	print FH "\n";
	print FH "	virtual interface " . $agent_if . " vif;\n";
	print FH "\n";
	print FH "extern function new (string name ,uvm_component parent);\n";
	print FH "extern virtual function void build_phase (uvm_phase phase);\n";
	print FH "extern virtual function void connect_phase (uvm_phase phase);\n";
	print FH "extern task main_phase(uvm_phase phase);\n";
	print FH "extern task do_drive(${agent_item} req);\n";

	print FH "endclass : ". $agent_name . "_driver \n";
	print FH "\n\n";
	print FH "function ${agent_name}_driver::new(string name ,uvm_component parent);\n";
	print FH "	super.new(name,parent);\n";
	print FH "endfunction : new\n";
	print FH "\n";

	print FH "function void ${agent_name}_driver::build_phase(uvm_phase phase);\n";
	print FH "endfunction:build_phase\n";
	print FH "\n\n";

	print FH "function void ${agent_name}_driver::connect_phase(uvm_phase phase);\n";
	print FH "	super.connect_phase(phase);\n";
	print FH "	if(!uvm_config_db #(virtual $agent_if)::get(this,\"\",\"vif\",vif))\n";
	print FH "		`uvm_error(\"NOVIF\",\{\"virtual interface must be set for: \",get_full_name(),\".vif\"\})\n";
	print FH "endfuntion : connect_phase\n";
	print FH "\n\n";
	print FH "task" . $agent_name . "_driver::main_phase(uvm_phase phase); \n";
	print FH "	`uvm_info(get_type_name(),\"main_phase\",UVM_HIGH)\n";


	print FH "	forever\n";
	print FH "	begin\n";
	print FH "		seq_item_port.get_next_item(req);\n";


	print FH "			`uvm_info(get_type_name(),{\"req item\\n\",req.sprint},UVM_HIGH)\n";
	print FH "		do_drive(req);\n";

	print FH "		seq_item_port.item_done();\n";

	print FH "		#10ns;\n";

	print FH "	end\n";
	print FH "endtask : main_phase\n";
	print FH "\n\n";
	print FH "task" . $agent_name . "_driver::do_drive(${agent_item} req);\n\n";
	print FH "endtask : do_drive\n\n";


	print FH "`endif //" . uc($agent_name) . "_DRIVER_SV\n\n";
	close(FH);
}

sub gen_monitor{
	$dir = $project . "/verif/agent/" . $agent_name;
	open(FH, ">" . $dir . "/" . $agent_name . "_monitor.sv")
		||die("Exiting due to Error: can't open monitor: $agent_name");

	write_file_header "${agent_name}_monitor.sv","Monitor for $agent_name";


	print FH "`ifndef " . uc($agent_name) . "_MONITOR_SV\n";
	print FH "`define " . uc($agent_name) . "_MONITOR_SV\n\n";

	print FH "class ${agent_name}_monitor extends uvm_monitor;\n";
	print FH "\n";
	print FH "	`uvm_component_utils(" . $agent_name . "_monitor)\n";
	print FH "\n";
	print FH "	virtual interface $agent_if vif;\n\n";
	print FH "	uvm_analysis_port #(${agent_item}) analysis_port;\n";

	print FH "	${agent_item} m_trans;\n\n";
	
	print FH "extern function new (string name ,uvm_component parent);\n";
	print FH "extern virtual function void build_phase (uvm_phase phase);\n";
	print FH "extern virtual function void connect_phase (uvm_phase phase);\n";
	print FH "extern task main_phase(uvm_phase phase);\n";
	print FH "extern task do_mon();\n";
	print FH "\n";

	print FH "endclass : " .$agent_name . "_monitor \n";
	print FH "\n\n";
	print FH "function ${agent_name}_monitor::new(string name ,uvm_component parent);\n";
	print FH "	super.new(name,parent);\n";
	print FH "	analysis_port = new(\"analysis_port\",this);\n";
	print FH "endfunction : new\n";
	print FH "\n\n";

	print FH "function void ${agent_name}_monitor::build_phase(uvm_phase phase);\n";
	print FH "endfunction:build_phase\n";
	print FH "\n\n";

	print FH "function void ${agent_name}_monitor::connect_phase(uvm_phase phase);\n";
	print FH "	super.connect_phase(phase);\n";
	print FH "	if(!uvm_config_db #(virtual $agent_if)::get(this,\"\",\"vif\",vif))\n";
	print FH "		`uvm_error(\"NOVIF\",\{\"virtual interface must be set for: \",get_full_name(),\".vif\"\})\n";
	print FH "endfuntion : connect_phase\n";
	print FH "\n\n";

	print FH "task" . $agent_name . "_monitor::main_phase(uvm_phase phase); \n";
	print FH "	`uvm_info(get_type_name(),\"main_phase\",UVM_HIGH)\n";
	print FH "	m_trans = ${agent_item}::type_id::create(\"m_trans\");\n";
	print FH "	do_mon();\n";
	print FH "endtask : main_phase\n";
	print FH "\n\n";
	print FH "task ${agent_name}_monitor::do_mon();\n";
	print FH "endtask : do_mon\n";
	print FH "\n\n";

	print FH "`endif //" . uc($agent_name) . "_MONITOR_SV\n\n";
	close(FH);
}

sub gen_sequencer{
	$dir = $project . "/verif/agent/" . $agent_name;
	open(FH, ">" .$dir . "/" . $agent_name . "_sequencer.sv")
		||die("Exiting due to Error: can't open sequencer: $agent_name");
	write_file_header"${agent_name}_sequencer.sv","Sequencer for $agent_name";

	print FH "`ifndef " . uc($agent_name) . "_SEQUENCER_SV\n";
	print FH "`define " . uc($agent_name) . "_SEQUENCER_SV\n\n";

	print FH "class ${agent_name}_sequencer extends uvm_sequencer #(${agent_item})\n";
	print FH "\n";
	print FH "	`uvm_component_utils(" . $agent_name . "_sequencer)\n";
	print FH "\n";
	print FH "extern function new (string name ,uvm_component parent);\n";

	print FH "endclass : ". $agent_name . "_sequencer\n";
	print FH "\n\n";
	print FH "function ${agent_name}_sequencer::new(string name ,uvm_component parent);\n";
	print FH "	super.new(name,parent);\n";
	print FH "endfunction : new\n";
	print FH "`endif //" . uc($agent_name) . "_SEQUENCER_SV\n\n";
	close(FH);
}


sub gen_agent{
	my ($template_type) = @_;
	$dir = $project . "/verif/agent/" . $agent_name;
	open(FH, ">" . $dir . "/" .$agent_name . "_agent.sv")
		||die ("Exiting due to Error: can't open agent: $agent_name");

	write_file_header "${agent_name}_agent.sv","Agent for $agent_name";

	print FH "`ifndef " . uc($agent_name) . "_AGENT_SV\n";
	print FH "`define " . uc($agent_name) . "_AGENT_SV\n\n";

	print FH "class ${agent_name}_agent extends uvm_agent;\n";
	print FH "\n";
	print FH "	${agent_name}_agent_config     m_cfg;\n";
	if($template_type eq "act"){
	print FH "	${agent_name}_sequencer        m_sequencer;\n";
	print FH "	${agent_name}_driver           m_driver;\n";
	}
	print FH "	${agent_name}_monitor          m_monitor;\n\n";

	print FH "	uvm_analysis_port #(${agent_item}) analysis_port;\n";
	print FH "	`uvm_component_utils_begin(${agent_name}_agent)\n";
	print FH "		`uvm_field_enum(uvm_active_passive_enum,is_active,UVM_DEFAULT)\n";
	print FH "		`uvm_field_object(m_cfg,UVM_DEFAULT | UVM_REFERENCE)\n";
	print FH "	`uvm_component_utils_end";
	print FH "\n\n";
	

	print FH "\n";
	print FH "extern function new (string name ,uvm_component parent);\n";
	print FH "\n";
	
	print FH "extern virtual function void build_phase (uvm_phase phase);\n";
	print FH "extern virtual function void connect_phase (uvm_phase phase);\n";
	
	print FH "\n";

	print FH "endclass : " . $agent_name . "_agent \n";
	print FH "\n\n";

	print FH "function ${agent_name}_agent::new(string name ,uvm_component parent);\n";
	print FH "	super.new(name,parent);\n";
	print FH "	analysis_port = new(\"analysis_port\",this);\n";
	print FH "endfunction : new\n";
	print FH "\n\n";

	print FH "function void ${agent_name}_agent::build_phase(uvm_phase phase);\n";
	print FH "	super.build_phase(phase);\n";
	print FH "\n";
	print FH "	if(m_cfg == null) begin\n";
	print FH "		if(!uvm_config_db #(${agent_name}_agent_config)::get(this,\"\",\"m_cfg\",m_cfg))\n		begin\n";
	print FH "			`uvm_warning(\"NOCONFIG\",\"Config not set for Rx agent, using default is_active field\")\n";
	print FH "			m_cfg = ${agent_name}_agent_config::type_id::create(\"m_cfg\",this);\n";
	print FH "		end\n";
	print FH "	end\n";
	print FH "	is_active = m_cfg.is_active;\n";



	print FH "\n";

	print FH "	m_monitor           = ${agent_name}_monitor   ::type_id::create(\"m_monitor\",this);\n";

	if($template_type eq "act"){
		print FH "	if(is_active == UVM_ACTIVE)\n";
		print FH "	begin\n";
		print FH "		m_driver    = ${agent_name}_driver    ::type_id::create(\"m_driver\",this); \n";
		print FH "		m_sequencer = ${agent_name}_driver    ::type_id::create(\"m_sequencer\",this);\n";
		print FH "	end\n";
	}
	print FH "\n";
	print FH "endfunction:build_phase\n";
	print FH "\n\n";

	print FH "function void ${agent_name}_agent::connect_phase(uvm_phase phase);\n";
	print FH "	super.connect_phase(phase);\n";



	print FH "	m_monitor.analysis_port.connect(analysis_port);\n";

	if($template_type eq "act"){
		print FH "	if(is_active == UVM_ACTIVE)\n";
		print FH "	begin\n";
		print FH "		m_driver.seq_item_port.connect(m_sequencer.seq_item_export);\n";
		print FH "	end\n";
	}
	print FH "\n";

	print FH "endfunction : connect_phase\n";
	print FH "\n\n";















	print FH "`endif //" . uc($agent_name) . "_AGENT_SV\n\n";
	close(FH);
}

sub gen_seq{
	$dir = $project . "/verif/agent/" . $agent_name;
	open( FH, ">" . $dir . "/" . $agent_name . "_seq.sv")
		||die("Exiting due to Error: can't open seq: $agent_name");

	write_file_header "${agent_name}_seq.sv","Sequence for agent $agent_name";

	print FH "`ifndef " . uc($agent_name) . "_SEQ_SV\n";
	print FH "`define " . uc($agent_name) . "_SEQ_SV\n\n";

	print FH "class ${agent_name}_base_seq extends uvm_sequence #($agent_item);\n";
	print FH "\n";
	print FH "	`uvm_object_utils(" . $agent_name . "_base_seq)\n";
	print FH "\n";

	print FH "	function new(string name = \"$agent_name\_base_seq\");\n";
	print FH "		super.new(name);\n";	
	print FH "	endfunction \n\n";
	print FH "	virtual task pre_body();\n";
	print FH "		if(starting_phase != null)\n";
	print FH "		starting_phase.raise_objection(this,{\"Running sequence '\",\n";
	print FH "                                                        get_full_name(),\"'\"});\n";
	print FH "	endtask\n\n";
	print FH "	virtual task post_body();\n";
	print FH "		if(starting_phase != null)\n";
	print FH "			starting_phase.drop_objection(this,{\"Completed sequence '\",\n";
	print FH "                                                        get_full_name(),\"'\"});\n";
	print FH "	endtask\n\n";
	print FH "endclass : ".$agent_name . "_base_seq\n";
	print FH "//--------------------------------------------------------------------------------\n";

	print FH "class ${agent_name}_seq extends ${agent_name}_base_seq;\n";

	print FH "\n";
	print FH "	`uvm_object_utils(" . ${agent_name} . "_seq)\n";
	print FH "\n";
	print FH "	extern function new (string name = \"$agent_name\_seq\");\n";
	print FH "	extern task body();\n";
	print FH "\n";
	print FH "endclass : ". $agent_name . "_seq\n";
	print FH "\n\n";
	print FH "function ${agent_name}_seq::new(string name = \"$agent_name\_seq\");\n";
	print FH "	super.new(name);\n";
	print FH "endfunction :new\n";
	print FH "\n\n";
	print FH "task ${agent_name}_seq::body();\n";
	print FH "	`uvm_info(get_type_name(),\"Default sequence starting\",UVM_HIGH)\n\n";
	print FH "	req = " . ${agent_item} ."::type_id::create(\"req\");\n";
	print FH "	start_item(req);\n";
	print FH "	if(!req.randomize())\n";
	print FH "		`uvm_error(get_type_name,\"Failed to randomize transaction\")\n";
	print FH "	finish_item(req);\n";
	print FH "	`uvm_info(get_type_name(),\"Default sequence completed\",UVM_HIGH)\n";
	print FH "endtask : body\n";
	print FH "\n\n";

	print FH "`endif //" . uc($agent_name) . "_SEQ_LIB_SV\n\n";

	close(FH);
}

sub gen_agent_pkg{
	my($template_type) = @_;

	$dir = $project . "/verif/agent/" . $agent_name;
	open( FH, ">" . $dir . "/" . $agent_name . "_pkg.sv")
		||die("Exiting due to Error: can't open include file: $agent_name");

	write_file_header "${agent_name}_pkg.sv","Package for agent $agent_name";
	print FH "`ifndef " . uc($agent_name) . "_PKG_SV\n";
	print FH "`define " . uc($agent_name) . "_PKG_SV\n\n";

	print FH "package ${agent_name}_pkg;\n\n";
	print FH "	import uvm_pkg::*;\n";
	print FH "	`include\"uvm_macros.svh\"\n\n";
	print FH "	`include\"${agent_item}.sv\"\n";
	print FH "	`include\"".$agent_name . "_agent_config.sv\"\n";
	print FH "	`include\"".$agent_name . "_monitor.sv\"\n";

	if($template_type eq "act"){
		print FH "	`include\"".$agent_name . "_driver.sv\"\n";
		print FH "	`include\"".$agent_name . "_sequencer.sv\"\n";

		print FH "	`include\"".$agent_name . "_seq.sv\"\n";
	}
	print FH "	`include\"".$agent_name . "_agent.sv\"\n";
	print FH "\n";
	print FH "endpackage : ${agent_name}_pkg \n\n";
	print FH "`endif //" . uc($agent_name) . "_PKG_SV\n\n";

	close(FH);
}

sub gen_top_config{
	$dir = $project . "/verif/env";
	open( FH, ">" . $dir . "/" . $envname . "_config.sv")
		||die("Exiting due to Error: can't open config: $agent_name");

	write_file_header "${envname}_config.sv","Configuration for $envname";
	
	print FH "`ifndef " . uc($envname) . "_CONFIG_SV\n";
	print FH "`define " . uc($envname) . "_CONFIG_SV\n\n";

	print FH "class ${envname}_config extends uvm_object;\n";
	print FH "\n";
	print FH "	`uvm_object_utils(${envname}_config)\n";


	print FH "\n";

	print FH "\n";

	print FH "	extern function new (string name = \"${envname}_config\");\n";
	print FH "\n";


	print FH "endclass : " . ${envname} ."_config\n";
	print FH "\n\n";
	print FH "function ${envname}_config::new(string name = \"${envname}_config\");\n";
	print FH "	super.new(name);\n";
	print FH "endfunction : new\n";
	print FH "\n\n";


	print FH "`endif //" . uc($envname) . "_CONFIG_SV\n\n";
	close(FH);
}

sub gen_refm{
	$dir = $project . "/verif/env/";
	open( FH, ">" . $dir . "/" . $tbname . "_refm.sv")
		||die("Exiting due to Error: can't open file: $tbname");
	write_file_header "${tbname}_refm.sv","Refm for $tbname";
	
	print FH "`ifndef" . uc($tbname) . "_REFM_SV\n";
	print FH "`define" . uc($tbname) . "_REFM_SV\n\n";

	print FH "class ${tbname}_refm extends uvm_component;\n";
	print FH "\n";
	print FH "	`uvm_component_utils(" . ${tbname} . "_refm)\n";
	print FH "\n";
	
	print FH "	extern function new(string name, uvm_component parent);\n\n";
	print FH "	extern task main_phase(uvm_phase phase);\n";

	print FH "endclass : " . ${tbname} ."_refm\n";
	print FH "\n\n";
	print FH "function ${tbname}_refm::new(string name, uvm_component parent);\n";
	print FH "	super.new(name,parent);\n";
	print FH "endfunction : new\n";
	print FH "\n\n";
	print FH "task ${tbname}_refm::main_phase(uvm_phase phase);\n";
	print FH "endtask : main_phase\n\n";
	print FH "`endif // " . uc($tbname) . "_REFM_SV\n\n";
	close(FH);
}

sub gen_scb{
	$dir = $project . "/verif/env/";
	open( FH, ">" . $dir . "/" . $tbname . "_scb.sv")
		||die("Exiting due to Error: can't open file: $tbname");
	write_file_header "${tbname}_refm.sv","Scb for $tbname";
	
	print FH "`ifndef " . uc($tbname) . "_SCB_SV\n";
	print FH "`define " . uc($tbname) . "_SCB_SV\n\n";

	print FH "class ${tbname}_scb extends uvm_component;\n";
	print FH "\n";
	print FH "	`uvm_component_utils(" . $tbname . "_scb)\n";
	print FH "\n";
	print FH "	extern function new(string name, uvm_component parent);\n\n";
	print FH "	extern task main_phase(uvm_phase phase);\n";

	print FH "endclass : " . ${tbname} ."_scb\n";
	print FH "\n\n";
	print FH "function ${tbname}_refm::new(string name, uvm_component parent);\n";
	print FH "	super.new(name,parent);\n";
	print FH "endfunction : new\n";
	print FH "\n\n";
	print FH "task ${tbname}_refm::main_phase(uvm_phase phase);\n\n";
	print FH "endtask : main_phase\n\n";
	print FH "`endif // " . uc($tbname) . "_SCB_SV\n\n";
	close(FH);
}

 sub gen_top_env{
	$dir = $project . "/verif/env";
	open( FH, ">" . $dir . "/" . $tbname . "_env.sv")
		||die("Exiting due to Error: can't open env: $tbname");
	write_file_header "${tbname}_env.sv","Env for $tbname";
	
	print FH "`ifndef " . uc($tbname) . "_ENV_SV\n";
	print FH "`define " . uc($tbname) . "_ENV_SV\n\n";

	print FH "class ${tbname}_env extends uvm_env;\n";
	print FH "\n";
	print FH "	`uvm_component_utils(" . $tbname . "_env)\n";
	print FH "\n";



	my @list1;
	my @list2;
	my @list3;
	my $aname;






























	foreach $aname (@agent_list){
		push @list1, "	${aname}_agent";
		push @list2, " m_${aname}_agent;";
		push @list1,"";
		push @list2,"";
	}














	if($regmodel_name ne ""){
		push @list1,"	//Register model\n";
		push @list2,"";
		push @list1,"	$regmodel_name";
		push @list2,"regmodel;";
	}


	push @list1, "	" . $tbname . "_refm	";
	push @list2, "m_refm;";
	push @list1,"	" . $tbname ."_scb	";
	push @list2,"m_scb;";

	push @list1,"	".$tbname . "_env_config	";
	push @list2,"m_env_config;\n";


	pretty_print(\@list1,\@list2,\@list3);
	print FH "extern function new (string name ,uvm_component parent);\n";
	print FH "extern virtual function void build_phase (uvm_phase phase);\n";
	print FH "extern virtual function void connect_phase (uvm_phase phase);\n";
	print FH "extern virtual function void end_of_elaboration_phase (uvm_phase phase);\n";

	print FH "\n";

	print FH "endclass : " . $tbname . "_env\n";
	print FH "\n\n";
	print FH "function ${tbname}_emv::new(string name ,uvm_component parent)\n";
	print FH "	super.new(name,parent);\n";
	print FH "endfunction : new\n";
	print FH "\n\n";

	print FH "function void ${tbname}_env::build_phase(uvm_phase phase)\n";
	print FH "	`uvm_info(get_type_name(),\"In build_phase\",UVM_HIGH)\n";

	print FH "	if(!uvm_config_db #(${tbname}_env_config)::get(this,\"\",\"m_env_config\",m_env_config))\n";
	print FH 
		"	`uvm_error(get_type_name(),\"Unable to get ${tbname}_env_config\")\n";

	print FH "	m_refm =  ${tbname}_refm::type_id::create(\"m_refm\",this);\n";
	print FH "	m_scb  =  ${tbname}_scb ::type_id::create(\"m_scb\",this);\n";

	do{
		print FH "\n";
		print FH "	regmodel = ${regmodel_name}::type_id::create(\"regmodel\");\n";
		print FH "	regmodel.build();\n";
		print FH "\n";
	}if $regmodel and $regmodel_name ne "";








	@list1=();
	@list2=();
	@list3=();

































































	print FH "\n";






	foreach my $aname (@agent_list){
		print FH "	m_${aname}_agent = ${aname}_agent::type_id::create(\"m_${aname}_agent\",this);\n";
	}











	print FH "\n";



	print FH "endfunction : build_phase\n";
	print FH "\n\n";

	print FH "function void ${tbname}_env::connect_phase(uvm_phase phase);\n";
	print FH "	`uvm_info(get_type_name(),\"In connect_phase\",UVM_HIGH)\n";







	foreach my $aname(@agent_list){

	}


































	print FH "\n";

	print FH "endfunction : connect_phase\n";
	print FH "\n\n";

	print FH "//Could print out diagnostic information,for example\n";
	print FH "function void ${tbname}_env::end_of_elaboration_phase(uvm_phase phase);\n";
	print FH "	//uvm_top.print_topology();\n";
	print FH "	//`uvm_info(get_type_name(),\$sformatf(\"Verbosity level is set to : %d\",get_report_verbosity_level()),UVM_MEDIUM)\n";
	print FH "	//`uvm_info(get_type_name(),\"Print all factory overrides\",UVM_MEDIUM)\n";
	print FH "	//factory.print();\n";
	print FH "endfunction : end_of_elaboration_phase\n";
	print FH "\n\n";

































	pretty_print(\@list1,\@list2,\@list3);



































	print FH "`endif // " . uc($tbname) . "_ENV_SV\n\n";
	close(FH);
}

 sub gen_top_test{
	$dir = $project . "/verif/tests";
	open( FH, ">" . $dir . "/" . $tbname . "_test_pkg.sv")
		||die("Can't open test: ". $tbname . "_test_pkg.sv");

	write_file_header "${tbname}_test_pkg.sv","TEST package for agent $tbname";

	print FH "`ifndef " . uc($tbname) . "_TEST_PKG_SV\n";
	print FH "`define " . uc($tbname) . "_TEST_PKG_SV\n\n";
	print FH "package " . $tbname . "_test_pkg;\n\n";
	print FH "	`include \"uvm_macros.svh\"\n\n";
	print FH "	import uvm_pkg::*;\n\n";
	print FH "	import regmodel_pkg::*;\n\n" if $regmodel;




	foreach my $agent(@agent_list){
		print FH "	import ${agent}_pkg::*;\n";
	}





	print FH "  	import " . $tbname . "_env_pkg;;*;\n";
	print FH "\n";
	print FH "	`include\"".$tbname . "_test_base.sv\"\n";
	print FH "\n";
	print FH "endpackage : " . $tbname . "_test_pkg\n\n";
	print FH "`endif // " . uc($tbname) . "_TEST_PKG_SV\n\n";
	close(FH);





	open( FH, ">" . $dir . "/" . $tbname . "_test_base.sv")
		||die("Exiting due to Error: can't open test: " . $tbname . "_test_base.sv");


	write_file_header "${tbname}_test_base.sv","TEST class for agent ${tbname} (include in package ${tbname}_test_pkg)";

	print FH "`ifndef " . uc($tbname) . "_TEST_BASE_SV\n";
	print FH "`define " . uc($tbname) . "_TEST_BASE_SV\n\n";	


	print FH "class ${tbname}_test_base extends uvm_test;\n";
	print FH "\n";
	print FH "	`uvm_component_utils(" . $tbname ."_test_base)\n";
	print FH "\n";
	print FH "	${tbname}_env        m_env;\n";
	print FH "	${tbname}_env_config m_env_config;\n";
	print FH "\n";
	foreach my $agent(@agent_list){
		print FH "	$agent\_agent_config m_$agent\_agent_config;\n";
	}

	print FH "\n	extern function new (string name ,uvm_component parent=null);\n";
	print FH "	extern function void build_phase (uvm_phase phase);\n";
	print FH "	extern function void connect_phase (uvm_phase phase);\n";
	print FH "	extern function void end_of_elaboration_phase(uvm_phase phase);\n";
	print FH "	extern task main_phase(uvm_phase phase);\n";
	print FH "\n";

	print FH "endclass : ${tbname}_test_base\n";
	print FH "\n\n";
	print FH "function ${tbname}_test_base::new(string name ,uvm_component parent=null);\n";
	print FH "	super.new(phase)\n";
	print FH "endfunction : new\n";
	print FH "\n";

	print FH "function void ${tbname}_test_base::build_phase (uvm_phase phase);\n";
	print FH "	m_env       =${tbname}_env       ::type_id::create(\"m_env\",this);\n";
	print FH "	m_env_config=${tbname}_env_config::::type_id::create(\"m_env_config\",this);\n";

	foreach my $agent(@agent_list){
		print FH "	m_${agent}\_agent_config = $agent\_agent_config::type_id::create(\"m_$agent\_agent_config\",this);\n";
	} 
	print FH "\n";

	print FH "	void'(m_env_config.randomize());\n";
	print FH "	uvm_config_db#(${tbname}_env_config)::set(this,\"\*\",\"m_env_config\",m_env_config);\n";
	foreach my $agent(@agent_list){
		print FH "	void'(m_$agent\_agent_config.randomize());\n";
		print FH "	uvm_config_db#($agent\_agent_config)::set(this,\"m_env\",\"m_$agent\_agent_config\",m_$agent\_agent_config);\n";
	}


	print FH "\n";

	print FH "endfuntion : build_phase\n";
	print FH "\n\n";
	print FH "function void ${tbname}_test_base::connect_phase(uvm_phase phase);\n";
	print FH "\n";

	print FH "endfunction : connect_phase\n\n";

	print FH "function void ${tbname}_test_base::end_of_elaboration_phase(uvm_phase phase);\n";
	print FH "	uvm_top.print_topology();\n";
	print FH "	`uvm_info(get_type_name(),\$sformatf(\"Verbosity level is set to : %d\", get_report_verbosity_level()),UVM_MEDIUM)\n";
	print FH "	`uvm_info(get_type_name(),\"Print all factory override\",UVM_MEDIUM)\n";
	print FH "	factory.print();\n";
	print FH "endfunction : end_of_elaboration_phase\n";
	print FH "\n\n";
	print FH "task ${tbname}_test_base::main_phase(uvn_phase phase);\n\n";
	print FH "endtask : main_task\n\n";

	print FH "`endif // " . uc($tbname) . "_TEST_BASE_SV\n";
	close(FH);

}

 sub gen_top_pkg{
	
	
	$dir = $project . "/verif/env";
	open( FH, ">" . $dir . "/" . $tbname . "_env_pkg.sv")
		||die("Exiting due to Error: can't open include file : $tbname");

	write_file_header "${tbname}_env_pkg.sv","Package for agent $tbname";

	print FH "package" . $tbname ."_env_pkg;\n";
	print FH "	`include \"uvm_macros.svh\"\n\n";
	print FH "	import uvm_pkg::*;\n\n";
	print FH "	import regmodel_pkg::*;\n" if $regmodel;



	foreach my $agent(@agent_list){
		print FH "	import ${agent}_pkg::*;\n";
	}






		print FH "\n";
		print FH "	`include \"" . $tbname . "_env_config.sv\"\n";
		print FH "	`include \"" . $tbname . "_refm.sv\"\n";
		print FH "	`include \"" . $tbname . "_scb.sv\"\n";
		print FH "	`include \"" . $tbname . "_env.sv\"\n";
		print FH "\n";
		print FH "endpackage : ". $tbname ."_env_pkg\n\n";
		close(FH);
	
 }

 sub gen_top{
	$dir = $project."/verif/tb";
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	open(FH,">" . $dir."/".$tbname."_tb.sv")
		||die("Exiting due to Error: can't open include file : " . $tbname . "_tb.sv");
		


	write_file_header("${tbname}_tb.sv","Testbench");
	print FH "`timescale 1ns/1ns\n";
	print FH "module " . $tbname ."_tb\n";
	print FH "\n\n";


	print FH "	`include \"uvm_macros.svh\"\n\n";
	print FH "	import uvm_pkg::*;\n";
	foreach my $agent(@agent_list){
		print FH "	import ${agent}_pkg::*;\n";
	}


	print FH "	import ${tbname}_test_pkg::*;\n";
	print FH "	import ${tbname}_env_pkg::*;\n";
	print FH "\n";
	
	foreach my $agent (@agent_list){
		print FH "	${agent}_if m_${agent}_if();\n";
	}


	print FH "\n";





























































	print FH "	initial\n";
	print FH "	begin\n";
	foreach my $agent (@agent_list){
		print FH "	uvm_config_db #(virtual ${agent}_if)::set(null,\"\*\",\"${agent}_vif\",m_${agent}_if);\n";
	}
	print FH "\n";
	print FH "	run_test();\n";
	print FH "	end\n";
	print FH "\n";
	print FH "endmodule\n";
	close(FH);

 }

 sub gen_vcs_script{
	my $dir = $project . "/verif/sim";
	my $vcs_opts = 
	 	"vcs -sverilog -ntb_opts uvm -debug_pp -timescale=1ns/1ns \\\n";
	open(FH , ">" . $dir . "/Makefile")
		||die("Exiting due to Error: can't open file : Makefile");
	print FH "#!/bin/sh\n\n\n";
	print FH "RTL_PATH=../../rtl\n";
	print FH "TB_PATH=../../verif\n";
	print FH "VERB=UVM_MEDIUM\n";
	print FH "SEED=1\n";
	print FH "TEST=${tbname}_test_base\n\n";
	print FH "all:comp run\n";

	print FH "comp:\n";
	print FH "\t$vcs_opts";
	gen_compile_file_list();
	print FH "	-l com.log\n\n";

	print FH "run:\n";
	print FH "\t./simv +UVM_TESTNAME=\${TEST} +UVM_VERBOSITY=\${VERB} +ntb_random_seed=\${SEED} -l \${TEST.log}\n\n";

	print FH "dve:\n";
	print FH "\tdve -vpd vcdplus.vpd&\n\n";

	print FH "clean:\n";
	print FH "\trm -rf csrc simv\n";

	close(FH);

	chmod(0755, $dir . "/Makefile");
 }

 sub gen_compile_file_list{
	my $incdir = "	+incdir+../tb \\\n";

	foreach my $agent(@agent_list){
		if(($agent ne "")){
			$incdir .= "	+incdir+../agent/${agent}\\\n";
		}
	}


	$incdir .= "	+incdir+../tests \\\n";
	$incdir .= "	+incdir+../tests/seqlib \\\n";
	$incdir .= "	+incdir+../env \\\n";
	print FH "$incdir";

	foreach my $agent (@agent_list){
		if(($agent ne "")){
			print FH "	../agent/${agent}/${agent}_pkg.sv \\\n";
			print FH "	../agent/${agent}/${agent}_if.sv \\\n";
		}
	}

	print FH "	../env/${tbname}_env_pkg.sv \\\n";
	print FH "	../tests/${tbname}_test_pkg.sv \\\n";
	print FH "	../tb/${tbname}_tb.sv \\\n";
 }
