use Template;
use Parse::CSV;
use Data::Dumper;
use DateTime;  

sub age_gen{
    my $key = shift;
    my $result = shift;
    my $scale = $result->{"$key (Scale)"};
    my $unit = $result->{"$key (Unit)"};
    if($scale eq '' || $unit eq ''){
        return undef;   
    }
    else{
  
        return $scale." ".lc($unit);
    }
}

sub parse_profiles {
my $profiles = shift;
my @profile_list = split(";",$profiles);
if(scalar @profile_list == 0){
return undef;
}
else{
my @ids = map {$ ~= s/\D//rg } @profile_list;
return  join(",",@ids);
}

}
 
my $csv = Parse::CSV->new(
    file => $ARGV[0],
    names => 1
);
my $date_time =  DateTime->now;  
my $date_string = $date_time->strftime( '%Y-%m-%d' ); 
my $run_folder = "./$date_string";
my $output_folder = "$run_folder/scripts";
my $trial_folder = "$output_folder/trial";
my $purge_folder = "$output_folder/purge";
mkdir $run_folder unless -d $run_folder;
mkdir $output_folder unless -d $output_folder;
mkdir $trial_folder unless -d $trial_folder;
mkdir $purge_folder unless -d $purge_folder;

my @results;
my $tt = Template->new({
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";
while ( my $ref = $csv->fetch ) {
    my $result = {};
    # remove ID
    my $ou_name = $ref->{'Choose your library system'} =~ s/[\d\)\(]//rg;
    #trim whitespace
    $ou_name =~ s/\s+$//;
    #replace internal spaces with _
    $ou_name =~ s/\s/_/g;
    $ou_id = $ref->{'Choose your library system'} =~ s/\D//rg;

    $result->{home_ou} = $ou_id;
    my $last_circ_t = age_gen('Last Circulation',$ref);
    my $last_hold_t = age_gen('Last Hold',$ref);
    my $last_payment_t = age_gen('Last Payment',$ref);
    my $last_activity_t = age_gen('Last Activity',$ref);
    $result->{last_circ} = $last_circ_t if $last_circ_t;
    $result->{last_hold} = $last_hold_t if $last_hold_t;
    $result->{last_payment} = $last_payment_t if $last_payment_t;
    $result->{last_activity} = $last_activity_t if $last_activity_t;
    $result->{profile} = parse_profiles($ref->{'Profile Group'});
    $result->{profile_exclude} = index($ref->{'Profile Options'}, 'Exclude') != -1 ? 'not ' : '';    
    #unless($ref->{'Active'} eq ''){
    #    $result->{active} = index($ref->{'Active'}, 'not') != -1 ? ' not ':' ';
    #}
    #unless($ref->{'Deleted'} eq ''){
    #    $result->{deleted} = index($ref->{'Deleted'}, 'not') != -1 ? ' not ':' ';
    #}
    unless($ref->{'Account Expiration Date'} eq ''){
        $result->{expire_date} = $ref->{'Account Expiration Date'};
    }
    unless($ref->{'Account Creation Date'} eq ''){
        $result->{create_date} = $ref->{'Account Creation Date'};
    }
    unless($ref->{'Open Circulation Count'} eq ''){
        $result->{circ_count} = $ref->{'Open Circulation Count'};
    }
    unless($ref->{'Lost Item Count'} eq ''){
        $result->{lost_count} = $ref->{'Lost Item Count'};
    }
    unless($ref->{'Maximum Overdue Fine'} eq ''){
        $result->{max_fine} = $ref->{'Maximum Overdue Fine'};
    }
    unless($ref->{'Maximum Lost Item Fine'} eq ''){
        $result->{max_lost_fine} = $ref->{'Maximum Lost Item Fine'};
    }
    unless($ref->{'Barred Patrons'} eq ''){
        $result->{barred} = index($ref->{'Barred Patrons'}, 'not') != -1 ? ' not ':' ';
    }  
    
    my $purge_sqlname = $purge_folder."/survey_query_".lc($ou_name)."_".$ou_id.".sql";
    my $trial_sqlname = $trial_folder."/survey_trial_".lc($ou_name)."_".$ou_id.".sql";
    print("Processing ".$purge_sqlname."\n");
    	$tt->process('purge.sql.tt2', $result,$purge_sqlname)
    || die $tt->error(), "\n";
    $result->{trial_mode} = true;
    print("Processing ".$trial_sqlname."\n");
    	$tt->process('purge.sql.tt2', $result,$trial_sqlname)
    || die $tt->error(), "\n";
}

    