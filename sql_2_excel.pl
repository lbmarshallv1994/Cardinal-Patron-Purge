use strict;
use warnings;
use Template;
use DBI;
use Net::OpenSSH;
use Config::Tiny;
use File::Spec;
use File::Path;
use File::Basename;
use Excel::Writer::XLSX;
use DateTime;  

sub add_worksheet{
    my $workbook = shift;
    my $name = shift;
    # init file
    my @headers = ("Patron Link","Selected For Purge","Creation Date","Expiration Date","Last Hold Date","Last Activity Date","Items Checked Out","Items Lost","Items Claimed Returned","Outstanding Fines","Outstanding Lost Item Fines");
    my $worksheet = $workbook->add_worksheet($name);
    $worksheet->write_row('A1',\@headers);
    $worksheet->set_column( 0, 0, 70 );    # Column  A   width set to 40
    $worksheet->set_column( 2, 5, 20 );    # Column  C,D,E,F   width set to 20
    $worksheet->set_column( 9, 10, 30 );    # Column  H   width set to 30
    return $worksheet;
}

my $config = Config::Tiny->read( "sql_connection.ini", 'utf8' );
my $subdomains;
unless($config->{EVERGREEN}{subdomains} eq ''){
    print("loading subdomains from ".$config->{EVERGREEN}{subdomains}."\n");
    $subdomains = Config::Tiny->read( $config->{EVERGREEN}{subdomains}, 'utf8' );
}

#excel has a hard 65,530 limit on how many URLs can exist per worksheet.
my $url_limit = 65530;
#ssh host
my $total_time_start = time();

#database name
my $db = $config->{PSQL}{db};
#database hostname
my $host = $config->{PSQL}{host};
#database port
my $port = $config->{PSQL}{port};
my $ssh_db_port = $config->{SSH}{db_port};
my $key_name = $config->{SSH}{keyname};
my $ssh_host = $config->{SSH}{host};
my $date_time =  DateTime->now;  
my $date_string = $date_time->strftime( '%Y-%m-%d' ); 
my $run_folder = "./$date_string";
my $output_folder = "$run_folder/output";
my $sqldir = $ARGV[0];
my $ssh;
#set up SSH tunnel
if( $config->{SSH}{enabled} eq 'true'){
    $ssh = Net::OpenSSH->new($ssh_host,key_path => $key_name, master_opts => [-L => "127.0.0.1:$port:localhost:$ssh_db_port"]) or die;
}
my $dsn = "dbi:Pg:dbname='$db';host='$host';port='$port';";
#database username
my $usr = $config->{PSQL}{username};
# database password
my $pwrd = $config->{PSQL}{password};
# link to patron's account
my $patron_url = $config->{EVERGREEN}{patron_url};
my $dbh =DBI->connect($dsn, $usr, $pwrd, {AutoCommit => 0}) or die ( "Couldn't connect to database: " . DBI->errstr );

# get org unit name and shortnames
my $org_st = $dbh->prepare("select * from actor.org_unit");
my %org_name; 
my %org_shortname; 
my %org_parent; 
print("Retrieving org unit data\n");
$org_st->execute();
for((0..$org_st->rows-1)){
    my $sql_hash_ref = $org_st->fetchrow_hashref;
    $org_name{$sql_hash_ref->{'id'}} = $sql_hash_ref->{'name'}; 
    $org_shortname{$sql_hash_ref->{'id'}} = $sql_hash_ref->{'shortname'}; 
    $org_parent{$sql_hash_ref->{'id'}} = $sql_hash_ref->{'parent_ou'}; 
    # remove directory if it exists so we will have fresh results
    my $sys_dir = "$output_folder/$sql_hash_ref->{'shortname'}";
    if(-d $sys_dir){
        print("removing $sys_dir\n");
        rmtree($sys_dir);
    }
}
$org_st->finish();
my @files;
if(-d $sqldir){
@files = glob $sqldir."/*.sql";
}
elsif(-f $sqldir){
push(@files,$sqldir);
}
else{
print("No file or directory $sqldir found");
die;
}
# iterate over all SQl scripts in the sql directory
foreach my $sql_file (@files) {
    my ($report_title,$dir,$ext) = fileparse($sql_file,'\..*');
    my $current_system = $report_title =~ s/\D//rg;
    # send staff to the right subdomain for their system
    my $subdomain ="https://";
    if(defined($subdomains) &&  exists($subdomains->{SUBDOMAINS}{$current_system})){
        # load subdomains from config file
        $subdomain .= lc($subdomains->{SUBDOMAINS}{$current_system}).".";
    }
    elsif($org_parent{$current_system} eq '1' || $current_system eq '102'){
        # use current system shortname if Mauney or Cleveland
        $subdomain .= lc($org_shortname{$current_system}).".";
    }
    else{
        # use parent system shortname
        $subdomain .= lc($org_shortname{$org_parent{$current_system}}).".";
    }
    print "running " . $report_title . "\n";
    open my $fh, '<', $sql_file or die "Can't open file $sql_file!";
    my $statement_body = do { local $/; <$fh> };

    # prepare statement
    my $sth = $dbh->prepare($statement_body);
    my $start_time = time();

    $sth->execute();   
    my $header_ref = $sth->{NAME_lc};
    my $data_ref = $sth->fetchall_arrayref();
    my @data = @$data_ref;
    $sth->finish;
    my $l = $#data + 1;
    my $complete_time = (time() - $start_time)/60.0;
    print("retrieved $l rows in $complete_time minutes\n");
    my $current_count = 1;
    $current_count = 1;   
    # end previous file
    my $sys_dir = "$output_folder/$org_shortname{$current_system}";
    mkdir $sys_dir unless -d $sys_dir;
    my $file_name = $sys_dir."/".$report_title.".xlsx";
    my $workbook =  Excel::Writer::XLSX->new($file_name);

    # init file
    my $purge_worksheet = add_worksheet($workbook,"Will Purge");
    my $pcount = 2;
    my $psheet = 1;

    
    # for each row returned
    for(my $i = 0; $i < $l; $i++){
        my $sql_row_ref = $data[$i];
        my @sql_row = @$sql_row_ref;
        my $patron_id = $sql_row[0];
        # set up link to patron account
        $sql_row[0] = "$subdomain$patron_url$patron_id/checkout";
        $sql_row[9] = sprintf "\$%.2f", $sql_row[9];
        $sql_row[10] = sprintf "\$%.2f", $sql_row[10];
        if($sql_row[1] == 1){           
            $purge_worksheet->write_row("A$pcount",\@sql_row);
            $pcount += 1;
        }
        if($pcount >= $url_limit){
            $pcount = 2;
            $psheet++;
            $purge_worksheet = add_worksheet($workbook,"Will Purge pt. $psheet");
   
        }

    }

    my $unpurge_worksheet = add_worksheet($workbook,"Won't Purge");     
    my $ucount = 2;
    my $usheet = 1;

    for(my $i = 0; $i < $l; $i++){
        my $sql_row_ref = $data[$i];
        my @sql_row = @$sql_row_ref;
        my $patron_id = $sql_row[0];
        # set up link to patron account
        $sql_row[0] = "$subdomain$patron_url$patron_id/checkout";
        $sql_row[9] = sprintf "\$%.2f", $sql_row[9];
        $sql_row[10] = sprintf "\$%.2f", $sql_row[10];
        if($sql_row[1] != 1){
            $unpurge_worksheet->write_row("A$ucount",\@sql_row);
            $ucount += 1;
        }

        if($ucount >= $url_limit){
            $ucount = 2;
            $usheet++;
            $unpurge_worksheet = add_worksheet($workbook,"Won't Purge pt. $usheet");        
        }
    }
    $workbook->close(); 
}
# close connection to database       
$dbh->disconnect;
#log completion time   
my $complete_time = (time() - $total_time_start)/60.0;
print("script finished in $complete_time minutes\n");
     
