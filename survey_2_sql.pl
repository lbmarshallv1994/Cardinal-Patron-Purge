use Template;
use Parse::CSV;
use Data::Dumper;

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
my @profile_list = split(",",$profiles);
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

    $result->{home_ou} = $ref->{'Choose your library system'} =~ s/\D//rg;
    my $last_circ_t = age_gen('Last Circulation',$ref);
    my $last_hold_t = age_gen('Last Hold',$ref);
    my $last_payment_t = age_gen('Last Payment',$ref);
    my $last_activity_t = age_gen('Last Activity',$ref);
    $result->{last_circ} = $last_circ_t if $last_circ_t;
    $result->{last_hold} = $last_hold_t if $last_hold_t;
    $result->{last_payment} = $last_payment_t if $last_payment_t;
    $result->{last_activity} = $last_activity_t if $last_activity_t;
    $result->{profile} = parse_profiles($ref->{'Profile Group'});
    
    unless($ref->{'Active'} eq ''){
        $result->{active} = index($ref->{'Active'}, 'not') != -1 ? ' not ':' ';
    }
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
    my $sqlname = "survey_query_".lc($ou_name).".sql";
    print("Processing ".$sqlname."\n");
    	$tt->process('purge.sql.tt2', $result,$sqlname)
    || die $tt->error(), "\n";
}

    