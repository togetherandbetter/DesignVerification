#！/usr/bin/perl -w
use Getopt::Long qw(:config pass_through);
&GetOptions(
	"reg_map_tbl=s" => \$reg_map_tbl,
	"module_name=s" => \$module_name,
	"h" => \$help
);
if(defined $help){
	die "uasge:uvm_ral_gen.pl -reg_map_tbl reg_map.csv -module_name i2c\n";
}
if(not defined $reg_map_tbl){
	$reg_map_tbl = "reg_map.csv";
}
my $skip_first_line_num = 1;
my $reg_model_name;
my $reg_block_name;

if(defined $module_name ){
	$reg_model_name = "$module_name\_reg_model.sv";
	$reg_block_name  = "$module_name\_reg_block.sv";
}
else{
	$reg_model_name  = "reg_model.sv";
	$reg_block_name  = "reg_block.sv";
}

open(reg_map_csv,"$reg_map_tbl")or die "can not open the file : $reg_map_tbl\n";
unlink "$reg_model_name" if (-e "$reg_model_name");
open(reg_model,">>$reg_model_name");
unlink "$reg_block_name" if (-e "$reg_block_name");
open(reg_block,">>$reg_block_name");
my %reg_addr_name;
my %reg_acc_name;
my %reg_bkdr;
my $indv;
my $line_cnt=0;
print "gen reg_model ...\n";
while(my $line=<reg_map_csv>){
	chomp($line);
	$line_cnt++;
	next if($line_cnt <= $skip_first_line_num);
	my $reg_name="";
	my $reg_addr;
	my $bkdr;
	my %reg_hash;
	my $reg_def_str;
	my @line_fields = split /,/,$line;
	if(@line_fields){
		$reg_name = $line_fields[0];
	}
	next if($reg_name eq "");
	$reg_name = ~ s/^\s*(\S+)\s*$/$1/;
	
	($reg_name,$reg_addr,%reg_hash) = &parse_reg(@line_fields);
	
	$reg_def_str =&gen_reg_model($reg_name,$reg_addr,%reg_hash);
	print reg_model $reg_def_str;
	$reg_addr_name{$reg_addr} = $reg_name;
	$reg_acc_name{$reg_addr} = $line_fields[34];
	$bkdr = $line_fields[36];
	if($bkdr=~/^\s*$/){
		$bkdr=$reg_name;
	}
	$reg_bkdr{$reg_addr}=$bkdr;
}
close reg_model;

&gen_reg_block_define;
&gen_reg_block(%reg_addr_name);
close reg_block;
print "done!\n";

#####################################################################
sub parse_reg{
	my(@line_fields)=@_;
	my $reg_name = "$line_fields[0]";
	my $reg_addr = "$line_fields[1]";
	my @reg_fields=();
	my %reg_hash;
	my $no_field=1;
	my $rstval;
	my $rst_q;
	my $line_field_cnt = @line_fields;
	$reg_name =~ s/^\s*(\S+)\s*$/\L$1/;
	$reg_addr =~ s/^\s*(\S+)\s*$/\L$1/;
	print "debug,line:@line_fields\n";
	$rstval = $line_fields[35];
	print "rstval = $rstval\n";
	#$rstval=~s/H//;
	my $val =hex($rstval);
	#print "rstval val = $val\n";
	my $valb= sprintf("%032b",$val);
	#print "rstval valb = $valb\n";
	#$valbe = pack("B32",$valb);
	#$valbe = pack("b",$valb);
	#my $valbe = chr($valb);
	#my $valbe = sprintf("%c",$valb);
	#print "rstval valbq size = $valbe\n";
	
	foreach my $i(0..31){
		#my $tempv = substr ($valb,$i,1);
		$rst_q[31-$i]=substr($valb,$i,1);
	}
	
#   foreach my $1(0..31){
#	print "----$rst_q[$i]\n";
#	}
#	$indv=$line_fields[39];
#	$indv=~/(\d)/;
#	$indv = $1;
	foreach my $cnt(2 .. 33){
		next if ($cnt >= $line_field_cnt);
		my $field = $line_fields[$cnt];
		next if ($field eq "");
		print "debug,cnt = $cnt\n";
		print "debug,field:$field\n";
		$no_field=0;
		my %reg_field_hash;
		$field =~s/^\s*(\S+)\s*$/$1/;
		my $field_name = $field;
		my $field_begin;
		my $field_end;
		my $field_width;
		my $valt;
		$valt = $valb;
		$field_name =~ s/\[.*//;
		$field_name =~ s/^\s*(\S+)\s*$/\L$1/;
		$field =~ s/63:32/31:0/;
		$field =~ s/95:64/31:0/;
		$field =~ s/127:96/31:0/;
		if($field =~ /\[(\d+):(\d+)\]/){
			my $s= $s1;
			my $e= $s2;
			if($e>=32){
				$e=$e%32;
				$s=$s%32;
			}
		$field_begin = 33- $cnt -$e;
		$field_width = $s- $e +1;
		$field_end = $field_begin+$field_width-1;
		print "debug1:field_begin = $field_begin\n";
		print "debug1:field_width = $field_width\n";
		my $temp1 = "";
		my $tempcnt = $field_width-1;
			foreach $i(0..$tempcnt){
				$temp1.=$rst_q[$field_end-$i];
			}
		$reg_field_hash{"field_defvalue"}=$temp1;
		print "temp1= $temp1\n";		
		}
		else{
			$field_begin = 33- $cnt;
			$field_width =1;
			$field_end =$field_begin+$field_width-1;
			print "debug2:field_begin = $field_begin\n";
			print "debug2:field_width = $field_width\n";
			$reg_field_hash{"field_defvalue"}=$rst_q[$field_begin];
		}
		if(exists $reg_hash{$field_name}){
			$field_width ++;
			my %field_hash = %{$reg_hash{$field_name}};
			if($field_begin > $field_hash{"field_begin"}){
				$field_begin= $field_hash{"field_begin"};
			}
		}
		$reg_field_hash{"field_name"}=$field_name;
		$reg_field_hash{"field_begin"}=$field_begin;
		$reg_field_hash{"field_width"}=$field_width;
		$reg_field_hash{"field_acc"}=$line_fields[34];
		#$reg_field_hash{"field_acc"}=$line_fields[13];
		#$reg_field_hash{"is_rand"}=$line_fields[14];
		#$reg_field_hash{"indv_acc"}=$indv;
		%{$reg_hash{$field_name}}=%reg_field_hash;
	}
	if($reg_name eq "t_lsb"){
		#die "die,debug;\n";
	}
	if($no_field ==1){
		my %reg_field_hash;
		$reg_field_hash{"field_name"}=$reg_name;
		$reg_field_hash{"field_begin"}=0;
		$reg_field_hash{"field_width"}=32;
		$reg_field_hash{"field_acc"}=$line_fields[34];
		#$reg_field_hash{"field_acc"}=$line_fields[13];
		#$reg_field_hash{"is_rand"}=$line_fields[14];
		#$reg_field_hash{"indv_acc"}=$indv;
		%{$reg_hash{$reg_name}}= %reg_field_hash;
	}
	my @keys = keys %reg_hash;
	#if($reg_name eq "cntl2"){
	#	die"debug die\n";
	#}
	return ($reg_name,$reg_addr,%reg_hash);
}

sub gen_reg_model{
	my ($reg_name,$reg_addr,%reg_hash) = @_;
	my $reg_def;
	$reg_def="class $reg_name\_reg extends uvm_reg;\n";
	foreach my $reg_fields(keys %reg_hash){
		my %reg_field_hash = %{$reg_hash{$reg_field}};
		$reg_def .= "	 rand uvm_reg_field $reg_field_hash{'field_name'};\n";
	}
	$reg_def .= "	`uvm_object_utils($reg_name\_reg)\n\n";
	$reg_def .= "	function new(input string name=\"$reg_name\");\n";
	$reg_def .= "		super.new(name,32,UVM_NO_COVERAGE);\n";
	$reg_def .= "	endfunction\n\n";
	$reg_def .= "	virtual function void build();\n";
	foreach my $reg_field (keys %reg_hash){
		my %reg_field_hash = %{$reg_hash{$reg_field}};
		$reg_def .= "	$reg_field_hash{'field_name'} = uvm_reg_field::type_id::create(\"$reg_field_hash{'field_name'}\");\n";
		$reg_def .= "	$reg_field_hash{'field_name'}.configure(this,$reg_field_hash{'field_width'},$reg_field_hash{'field_begin'},\"$reg_field_hash{'field_acc'}\",0,\'b$reg_field_hash{'field_defvalue'});\n";
	}
	$reg_def .= "	endfunction \n";
	$reg_def .= "endclass\n\n";
	return ($reg_def);
}


sub gen_reg_block_define{
	print reg_block "
	`define BUILD_REG_BLOCK(name,addr,type,bkdr)\\
	name = name``_reg::type_id::create(`\"name`\",get_full_name());\\
	name.configure(this,null,bkdr);\\
	name.build();\\
	dafault_map.add_reg(name,addr,type);\n\n"
}

sub gen_reg_block{
	print "gen reg_block...\n";
	my (%reg_addr_name) = @_;
	my $reg_block_def = "";
	$reg_block_def .= "class reg_block extends  uvm_reg_block;\n";
	foreach my$reg_addr(sort keys %reg_acc_name){
		my $reg_name = $reg_addr_name{$reg_addr};
		#my $reg_acc = $reg_acc_name{$reg_addr};
		#my $reg_bkdr = $reg_bkdr{$reg_addr};
		$reg_block_def .= "		rand $reg_name\_reg		$reg_name;\n";
	}
	
	$reg_block_def .= "
	`uvm_object_utils(reg_block)
	
	function new (input string name = \"reg_block\");
		super.new(name,UVM_NO_COVERAGE);
	endfunction
	
	function void build();
		default_map = create_map(\"default_map\",0,1,UVM_LITTLE_ENDIAN);\n";
	
	foreach my $reg_addr(sort keys %reg_addr_name){
		my $reg_name = $reg_addr_name{$reg_addr};
		my $reg_acc = $reg_acc_name{$reg_addr};
		my $reg_bkdr= $reg_bkdr{$reg_adddr};
		$reg_block_def .= "		`BUILD_REG_BLOCK($reg_name,\'h$reg_addr,\"$reg_acc\",\"$reg_bkdr\");\n";
	}
	$reg_block_def .= "		endfounction\n\n";
	$reg_block_def .= "endclass\n";
	print reg_block $reg_block_def;
}
