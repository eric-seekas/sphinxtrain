#!/usr/bin/perl
## ====================================================================
##
## Copyright (c) 1996-2000 Carnegie Mellon University.  All rights 
## reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
##
## 1. Redistributions of source code must retain the above copyright
##    notice, this list of conditions and the following disclaimer. 
##
## 2. Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in
##    the documentation and/or other materials provided with the
##    distribution.
##
## 3. The names "Sphinx" and "Carnegie Mellon" must not be used to
##    endorse or promote products derived from this software without
##    prior written permission. To obtain permission, contact 
##    sphinx@cs.cmu.edu.
##
## 4. Products derived from this software may not be called "Sphinx"
##    nor may "Sphinx" appear in their names without prior written
##    permission of Carnegie Mellon University. To obtain permission,
##    contact sphinx@cs.cmu.edu.
##
## 5. Redistributions of any form whatsoever must retain the following
##    acknowledgment:
##    "This product includes software developed by Carnegie
##    Mellon University (http://www.speech.cs.cmu.edu/)."
##
## THIS SOFTWARE IS PROVIDED BY CARNEGIE MELLON UNIVERSITY ``AS IS'' AND 
## ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
## THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
## PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL CARNEGIE MELLON UNIVERSITY
## NOR ITS EMPLOYEES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
## SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
## LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
## DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
## THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
## (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
## OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##
## ====================================================================
##
## Author: Ricky Houghton (converted from scripts by Rita Singh)
##


my $index;

# RAH Force passage of config file, or look for it one directory up.
if (lc($ARGV[0]) eq '-cfg') {
    $cfg_file = $ARGV[1];
    $index = 2;
    if (! -s $cfg_file) {
	print "-cfg specified, but unable to find file $ARGV[1]\n";
	exit -3;
    }
require $cfg_file;
} else {
    $cfg_file = "./sphinx_train.cfg";
    require $cfg_file;
    &ST_LogWarning("-cfg not specified, using the default ./sphinx_train.cfg");
    $index = 0 ;
}


#************************************************************************
# this script performs baum-welch training using s3 code for a 
# continuous mdef file.
# it needs as inputs an initial set of semicont models in s3 format
# a mdef file and cepstra with transcription files.
#************************************************************************

die "USAGE: $0 <iter> <part> <npart>" if ($#ARGV != ($index + 2));

$iter   = $ARGV[$index];
$part   = $ARGV[$index+1];
$npart  = $ARGV[$index+2];

#set mach = `~rsingh/51..tools/machine_type.csh`
#set BW   = ~rsingh/09..sphinx3code/trainer/bin.$mach/bw
$BW   = "$CFG_BIN_DIR/bw";

$output_buffer_dir = "$CFG_BASE_DIR/bwaccumdir/${CFG_EXPTNAME}_buff_${part}";
mkdir ($output_buffer_dir,0777) unless -d $output_buffer_dir;


if ($iter == 1) {
    $hmm_dir  = "$CFG_BASE_DIR/model_parameters/${CFG_EXPTNAME}.cd_semi_initial";
    $var2pass	 = "no";
} else {
    $hmm_dir      = "$CFG_BASE_DIR/model_parameters/${CFG_EXPTNAME}.cd_semi_$CFG_N_TIED_STATES";
    $var2pass	  = "yes";
}


$moddeffn    = "$CFG_BASE_DIR/model_architecture/${CFG_EXPTNAME}.$CFG_N_TIED_STATES.mdef";
$statepdeffn = $CFG_HMM_TYPE; # indicates the type of HMMs
$mixwfn  = "$hmm_dir/mixture_weights";
$mwfloor = 1e-8;
$tmatfn  = "$hmm_dir/transition_matrices";
$meanfn  = "$hmm_dir/means";
$varfn   = "$hmm_dir/variances";
$minvar  = 1e-4;


# aligned transcripts and the list of aligned files is obtained as a result
# of (03.) forced alignment

if ( $CFG_FORCEDALIGN eq "no" ) {
    $listoffiles = $CFG_LISTOFFILES;
    $transcriptfile = $CFG_TRANSCRIPTFILE;
} else {
    $listoffiles   = "$CFG_BASE_DIR/generated/${CFG_EXPTNAME}.alignedfiles";
    $transcriptfile  = "$CFG_BASE_DIR/generated/${CFG_EXPTNAME}.alignedtranscripts";
}

$topn     = $CFG_CI_TOPN;
$logdir   = "$CFG_LOG_DIR/07.cd-schmm";
$logfile  = "$logdir/${CFG_EXPTNAME}.$iter-$part.bw.log";
mkdir ($logdir,0777) unless -d $logdir;

$ctl_counter = 0;
open INPUT,"${CFG_LISTOFFILES}";
while (<INPUT>) {
    $ctl_counter++;
}
close INPUT;
$ctl_counter = int ($ctl_counter / $CFG_NPART) if $CFG_NPART;
$ctl_counter = 1 unless ($ctl_counter);

system ("cp $CFG_GIF_DIR/green-ball.gif $CFG_BASE_DIR/.02.bw.$iter.$part.state.gif");
&ST_HTML_Print ("\t<img src=$CFG_BASE_DIR/.02.bw.$iter.$part.state.gif> ");        
&ST_Log ("Baum welch starting for iteration: $iter ($part of $npart) ");
&ST_HTML_Print ("<A HREF=\"$logfile\">Log File</A>\n");

open LOG,">$logfile";

if (open PIPE, "$BW -moddeffn $moddeffn -ts2cbfn $statepdeffn -mixwfn	$mixwfn -mwfloor $mwfloor -tmatfn $tmatfn -meanfn $meanfn -varfn $varfn -dictfn $CFG_DICTIONARY -fdictfn $CFG_FILLERDICT -ctlfn $CFG_LISTOFFILES -part $part -npart $npart -cepdir $CFG_FEATFILES_DIR -cepext $CFG_FEATFILE_EXTENSION -lsnfn $CFG_TRANSCRIPTFILE -accumdir	$output_buffer_dir -varfloor $minvar -topn $topn -abeam 1e-90 -bbeam 1e-40 -agc $CFG_AGC -cmn $CFG_CMN -meanreest yes -varreest yes -2passvar $var2pass -tmatreest yes -feat $CFG_FEATURE -ceplen $CFG_VECTOR_LENGTH 2>&1 |") {

    $processed_counter = 0;
    &ST_Log ("\t\tProcessing $ctl_counter files: \t\t");
    $| = 1;				# Turn on autoflushing
    while (<PIPE>) {
	if (/(ERROR).*/) {
	    &ST_LogError ($_);
	}
	if (/(FATAL).*/) {
	    &ST_LogError ($_);
	    die "Received a fatal error";
	}
	print LOG "$_";
	# Keep track of progress being made.
	$processed_counter++  if (/.*(utt\>).*/);
	$percentage = int (($processed_counter / $ctl_counter) * 100);
	if (!($percentage % 10)) {
	    &ST_Log ("${percentage}% ") unless $printed;
	    $printed = 1;
	} else {
	    $printed = 0;
	}
    }
    close LOG;
    close PIPE;
    $| = 0;
    $date = &ST_DateStr ();
    print LOG "$date\n";
    close LOG;
    &ST_Log ("\tFinished\n");
    exit (0);
}

system ("cp $CFG_GIF_DIR/red-ball.gif $CFG_BASE_DIR/.02.bw.$iter.$part.state.gif");
&ST_LogError ("\tFailed to start $BW \n");    
exit (-1);
