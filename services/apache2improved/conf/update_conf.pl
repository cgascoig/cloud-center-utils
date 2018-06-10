#!/usr/bin/perl

$config_file 	= $ARGV[0];
$tmp_conf	= "/tmp/conf.tmp";


if ( ! -f $config_file ) {
        print "Config file $config_file not present \n";
        exit 1;
}

unlink($tmp_conf);

open(CONF_FILE,"<",$config_file) or die "Cannot open $config_file \n";
open(TMP_CONF,">",$tmp_conf) or die "Cannot open $tmp_conf for writing\n";

while($lines=<CONF_FILE>){
        if ( $lines =~ m/Directory \/var\/www\// ) {
                print TMP_CONF $lines;
                $lines = <CONF_FILE>;
                $lines =~ s/Indexes//;
        }
        if ( $lines =~ m/DocumentRoot \/var\/www\/html/ ) {
                $find = "\/var\/www\/html";
                $replace = "\/var\/www\/";
                $lines =~ s/$find/$replace/;
        }
        print TMP_CONF $lines;
}

close(TMP_CONF);
close(CONF_FILE);

rename($tmp_conf,$config_file) or die "Cannot move $tmp_conf to $config_file \n";
unlink($tmp_conf);

exit 0;
