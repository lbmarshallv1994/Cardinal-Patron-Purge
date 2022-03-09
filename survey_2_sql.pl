use Template;
use Parse::CSV;
use Data::Dumper;
use DateTime;  
use Time::Piece;


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
my $arg_count = $#ARGV + 1;
unless($arg_count > 0){
    die('usage: survey_2_sql survey_file [date_begin_range(year/month/day) date_end_range(year/month/day)]');
}
my $csv = Parse::CSV->new(
    file => $ARGV[0],
    names => 1
);
my $date_begin_range_string = $arg_count > 1 ? $ARGV[1] : undef;
my $date_end_range_string = $arg_count > 2 ? $ARGV[2] : undef;
my $date_begin_range = $date_begin_range_string ? Time::Piece->strptime($date_begin_range_string, "%Y/%m/%d") : undef;
my $date_end_range = $date_end_range_string ? Time::Piece->strptime($date_end_range_string, "%Y/%m/%d") : undef;
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
    my $ou_name = $ref->{'choose your library system'} =~ s/[\d\)\(]//rg;

    # calculate timestamp
    my $timestamp = Time::Piece->strptime(substr($ref->{"Timestamp"},0,10), "%Y/%m/%d");
    #print($timestamp+"\n\n");
    if($date_begin_range){
       
        if($date_end_range){
            unless($timestamp >= $date_begin_range && $timestamp <= $date_end_range){
                next();
            }        
        }
        else{
            unless($timestamp >= $date_begin_range){
                next();
            }
        }
    }
    #trim whitespace
    $ou_name =~ s/\s+$//;
    $ou_id = $ref->{'choose your library system'} =~ s/\D//rg;

    $result->{home_ou} = $ou_id;
    
    my $last_circ_t = age_gen('last circulation',$ref);
    my $last_hold_t = age_gen('last hold',$ref);
    my $last_payment_t = age_gen('last payment',$ref);
    my $last_activity_t = age_gen('last activity',$ref);
    $result->{last_circ} = $last_circ_t if $last_circ_t;
    $result->{last_hold} = $last_hold_t if $last_hold_t;
    $result->{last_payment} = $last_payment_t if $last_payment_t;
    $result->{last_activity} = $last_activity_t if $last_activity_t;
    $result->{profile} = parse_profiles($ref->{'profile group'});
    $result->{profile_exclude} = index($ref->{'profile options'}, 'Exclude') != -1 ? 'not ' : '';    
    #unless($ref->{'Active'} eq ''){
    #    $result->{active} = index($ref->{'Active'}, 'not') != -1 ? ' not ':' ';
    #}
    #unless($ref->{'Deleted'} eq ''){
    #    $result->{deleted} = index($ref->{'Deleted'}, 'not') != -1 ? ' not ':' ';
    #}
    print(Dumper($ref));
    unless($ref->{'account expiration date'} eq ''){
        $result->{expire_date} = $ref->{'account expiration date'};
    }
    unless($ref->{'account creation date'} eq ''){
        $result->{create_date} = $ref->{'account creation date'};
    }
    unless($ref->{'open circulation count'} eq ''){
        $result->{circ_count} = $ref->{'open circulation count'};
    }
    unless($ref->{'lost item count'} eq ''){
        $result->{lost_count} = $ref->{'lost item count'};
    }
    unless($ref->{'maximum overdue fine'} eq ''){
        $result->{max_fine} = $ref->{'maximum overdue fine'};
    }
    unless($ref->{'maximum lost item fine'} eq ''){
        $result->{max_lost_fine} = $ref->{'maximum lost item fine'};
    }
    unless($ref->{'barred patrons'} eq ''){
        $result->{barred} = index($ref->{'barred patrons'}, 'not') != -1 ? ' not ':' ';
        $result->{barred_display} = $ref->{'barred patrons'};
    }
    unless($ref->{'protected patrons'} eq ''){
        $result->{protected_users} = $ref->{'protected patrons'};
    }      
    $result->{alert_message} = "automatically set to inactive status via $ou_name policy";
    #replace internal spaces with _
    $ou_name =~ s/\s/_/g;   
    $ou_name =~ s/\.//g;   
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

    