# TODO
#worksheet for survey results
#totals worksheet:
#total amount being purged,
#total not purge,
#sum of items checked out
#sum of items lost
#sum of oustanding fines
#sum of lost item fines

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
use List::Util qw[min max];
use Data::Dumper;
# criteria constants
use constant {
    LAST_CIRC => 0,
    LAST_HOLD => 1,
    LAST_PAYMENT => 2,
    LAST_ACTIVITY => 3,
    EXPIRE => 4,
    CREATE => 5,
    PERM => 6,
    CIRC_COUNT => 7,
    LOST_COUNT => 8,
    MAX_FINE => 9,
    MAX_LOST_FINE => 10,
    BARRED => 11, 
    PROTECTED_USERS => 12
};


sub add_worksheet{
    my $workbook = shift;
    my $criteria_ref = shift;
    my @criteria = @$criteria_ref;
    my $name = shift;
    # init file
    my @headers = ("Patron Link","Selected For Purge","Permission Group","Creation Date","Expiration Date","Last Hold Date","Last Activity Date","Items Checked Out","Items Lost","Items Claimed Returned","Outstanding Fines","Outstanding Lost Item Fines");
    my $worksheet = $workbook->add_worksheet($name);
    $worksheet->write_row('A1',\@headers);
    # $worksheet->set_header(
    
    $worksheet->set_column( 0, 0, 70 );    # Column  A (URL)   width set to 70
    $worksheet->set_column( 1, 1, 5 );    # Column  B (sel)  width set to 5
    $worksheet->set_column( 2, 2, 20 );    # Column  C (profile) width set to 20
    $worksheet->set_column( 3, 6, 20 );    # Column  D,E,F,G (dates) width set to 20
    $worksheet->set_column( 7,9, 15 );    # Column  H,I,J (items)   width set to 20
    $worksheet->set_column( 10, 11, 30 );    # Column  K,L (money)  width set to 30
    $worksheet->set_column( 12, 12, 30 );    # Column  M width set to 30
    # set up formats
    my $green_format = $workbook->add_format(
    bg_color => '#1a3b1e',
    color => '#ffffff'
    );
    my $red_format = $workbook->add_format(
    bg_color => '#FFC7CE'
    );
    my $yellow_format = $workbook->add_format(
    bg_color => '#fffec7'
    );
    my $money_format = $workbook->add_format();     
    $money_format->set_num_format( '$0.00' );
    my $red_money_format = $workbook->add_format(
    bg_color => '#FFC7CE'
    );
    my $yellow_money_format = $workbook->add_format(
    bg_color => '#fffec7'
    );
    $red_money_format->set_num_format( '$0.00' );
    $yellow_money_format->set_num_format( '$0.00' );
#    if(!($criteria[PROTECTED_USERS] eq "")){
#        $worksheet->conditional_formatting( "A2:A65536",
#            {
#                type     => 'cell',
#                criteria => '>=',
#                value    => $criteria[MAX_FINE]*0.9,
#                format   => $red_money_format,
#            }
#        );
#    }
    # apply money format to all overdue fine cells
    $worksheet->conditional_formatting( "K2:K65536",
        {
            type     => 'no_errors',
            format   => $money_format,
        }
    );

    # over due fines formatting
    if(!($criteria[MAX_FINE] eq "")){
        # apply red format if outstanding fines within top 90% of maximum
        $worksheet->conditional_formatting( "K2:K65536",
            {
                type     => 'cell',
                criteria => '>=',
                value    => $criteria[MAX_FINE]*0.9,
                format   => $red_money_format,
            }
        );
        # apply yellow format if outstanding fines at or above half of the maximum
        $worksheet->conditional_formatting( "K2:K65536",
            {
                type     => 'cell',
                criteria => '>=',
                value    => $criteria[MAX_FINE]*0.5,
                format   => $yellow_money_format,
            }
        );
    }
    else{
        # apply yellow format if outstanding fines is above average
        $worksheet->conditional_formatting( "K2:K65536",
            {
                type     => 'average',
                criteria => 'above',
                format   => $yellow_money_format,
            }
        );    
    }

    # apply money format to all lost fine cells
    $worksheet->conditional_formatting( "L2:L65536",
        {
            type     => 'no_errors',
            format   => $money_format,
        }
    );
    if(!($criteria[MAX_LOST_FINE] eq "")){
        # apply red format if lost fines within 90% of maximum
        $worksheet->conditional_formatting( "L2:L65536",
            {
                type     => 'cell',
                criteria => '>=',
                value    => $criteria[MAX_LOST_FINE]*0.9,
                format   => $red_money_format,
            }
        );
        # apply yellow format if lost fines at or above half of the maximum
        $worksheet->conditional_formatting( "L2:L65536",
            {
                type     => 'cell',
                criteria => '>=',
                value    => $criteria[MAX_LOST_FINE]*0.5,
                format   => $yellow_money_format,
            }
        );
    }
    else{
        # apply yellow format if lost fines is above average
        $worksheet->conditional_formatting( "L2:L65536",
            {
                type     => 'average',
                criteria => 'above',
                format   => $yellow_money_format,
            }
        );    
    }
    if(!($criteria[CIRC_COUNT] eq "")){
        # apply red format if items out within 90% of maximum
        $worksheet->conditional_formatting( "H2:H65536",
            {
                type     => 'cell',
                criteria => '>=',
                value    => $criteria[CIRC_COUNT]*0.9,
                format   => $red_format,
            }
        );
        # apply yellow format if items out at or above half of the maximum
        $worksheet->conditional_formatting( "H2:H65536",
            {
                type     => 'cell',
                criteria => '>=',
                value    => $criteria[CIRC_COUNT]*0.5,
                format   => $yellow_format,
            }
        );
    }
    else{
    # apply yellow format if items out is above average
    $worksheet->conditional_formatting( "H2:H65536",
            {
                type     => 'average',
                criteria => 'above',
                format   => $yellow_format,
            }
        );    
    }
    if(!($criteria[LOST_COUNT] eq "")){
        # apply red format if items lost within 90% of maximum
        $worksheet->conditional_formatting( "I2:I65536",
            {
                type     => 'cell',
                criteria => '>=',
                value    => $criteria[LOST_COUNT]*0.9,
                format   => $red_format,
            }
        );
        # apply yellow format if items lost at or above half of the maximum
        $worksheet->conditional_formatting( "I2:I65536",
            {
                type     => 'cell',
                criteria => '>=',
                value    => $criteria[LOST_COUNT]*0.5,
                format   => $yellow_format,
            }
        );    
    }
    else{
        # apply yellow format if items lost is above average
        $worksheet->conditional_formatting( "I2:I65536",
            {
                type     => 'average',
                criteria => 'above',
                format   => $yellow_format,
            }
        );
    }    
    $worksheet->conditional_formatting( "J2:J65536",
        {
            type     => 'average',
            criteria => 'above',
            format   => $yellow_format,
        }
    ); 
    $worksheet->conditional_formatting( "A1:M1",
        {
            type     => 'no_errors',
            format   => $green_format,
        }
    ); 
    return $worksheet;
}

sub add_totals_worksheet {
    my $workbook = shift;
    my $criteria_ref = shift;
    my @criteria = @$criteria_ref;
    my $exp = $criteria[4];
    my @headers = ("Patrons Purged","Patrons Not Purged","Patrons Expired $exp","Percent of Patrons Purged","Total Items Checked Out","Total Items Lost","Total Items Claimed","Total Item Fines","Total Lost Fines","Total Money Purged");
    my $green_format = $workbook->add_format(
    bg_color => '#1a3b1e',
    color => '#ffffff'
    );
    my $worksheet = $workbook->add_worksheet("Totals");
    $worksheet->write_row('A1',\@headers);
    $worksheet->set_column( 0, 9, 20 );    # default column width of 20
    $worksheet->set_column( 7, 9, 30 );    # Column  G,H,I (money)  width set to 30
    $worksheet->conditional_formatting( "A1:J1",
    {
        type     => 'no_errors',
        format   => $green_format,
    }
    ); 
    return $worksheet;
}

sub create_criteria_worksheet{
    my $data_ref = shift;
    my $workbook = shift;
    my @headers;
    $headers[LAST_CIRC] = "Last Circ Time";
    $headers[LAST_HOLD] = "Last Hold Time";
    $headers[LAST_PAYMENT] = "Last Payment Time";
    $headers[LAST_ACTIVITY] = "Last Activity Time";
    $headers[EXPIRE] = "Expire Date";
    $headers[CREATE] = "Create Date";
    $headers[PERM] = "Permission Groups";
    $headers[CIRC_COUNT] = "Items Out";
    $headers[LOST_COUNT] = "Items Lost";
    $headers[MAX_FINE] = "Max Fine";
    $headers[MAX_LOST_FINE] = "Max Lost Fine";
    $headers[BARRED] = "Barred";
    $headers[PROTECTED_USERS] = "Protected Users";
    my $green_format = $workbook->add_format(
    bg_color => '#1a3b1e',
    color => '#ffffff'
    );
    my $worksheet = $workbook->add_worksheet("Purge Criteria");
    $worksheet->write_row('A1',\@headers);
    $worksheet->set_column( 0, 10, 20 );    # default column width of 20
    $worksheet->write_row("A".(2),$data_ref);
    $worksheet->conditional_formatting( "A1:M1",
        {
            type     => 'no_blanks',
            format   => $green_format,
        }
    ); 
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
mkdir $run_folder unless -d $run_folder;
mkdir $output_folder unless -d $output_folder;
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
    
    # get data
    $sth->execute();   
    my $header_ref = $sth->{NAME_lc};
    my $data_ref = $sth->fetchall_arrayref();
    my @data = @$data_ref;
    $sth->finish;
    
    # get criteria
    my @criteria;
    my $criteria_st = $dbh->prepare("select * from trial_criteria");
    $criteria_st->execute();   
    my $c_data_ref = $criteria_st->fetchall_arrayref();
    my @c_data = @$c_data_ref;
    $criteria_st->finish;

    my $c_sql_row_ref = $c_data[0];
    @criteria = @$c_sql_row_ref;   
    $criteria_st->finish();
    
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
    my $purge_worksheet = add_worksheet($workbook,\@criteria,"Will Purge");
    my $pcount = 2;
    my $psheet = 1;
    #totals
    my $purge_total = 0;
    my $unpurge_total = 0;
    my $items_checked_out = 0;
    my $items_lost = 0;
    my $items_claimed = 0;
    my $item_fines = 0;
    my $lost_fines = 0;
    my $total_money_lost = 0;
        
    # enter purged patrons into spreadsheet
    for(my $i = 0; $i < $l; $i++){
        my $sql_row_ref = $data[$i];
        my @sql_row = @$sql_row_ref;
        if($sql_row[1] == 1){           
            my $patron_id = $sql_row[0];
            # set up link to patron account
            $sql_row[0] = "$subdomain$patron_url$patron_id/checkout";
            $items_checked_out += $sql_row[7];
            $items_lost += $sql_row[8];
            $items_claimed += $sql_row[9];
            $item_fines += max(0,$sql_row[10]);
            $lost_fines += max(0,$sql_row[11]);
            $total_money_lost += max(0,$sql_row[10]) + max(0,$sql_row[11]);
            $purge_worksheet->write_row("A$pcount",\@sql_row);
            $pcount += 1;
            $purge_total += 1;
        }
        if($pcount >= $url_limit){
            $pcount = 2;
            $psheet++;
            $purge_worksheet = add_worksheet($workbook,\@criteria,"Will Purge pt. $psheet");
   
        }

    }

    my $unpurge_worksheet = add_worksheet($workbook,\@criteria,"Won't Purge");     
    my $ucount = 2;
    my $usheet = 1;
    
    # enter unpurged patrons into spreadsheet
    for(my $i = 0; $i < $l; $i++){
        my $sql_row_ref = $data[$i];
        my @sql_row = @$sql_row_ref;
        my $patron_id = $sql_row[0];
        # set up link to patron account

        if($sql_row[1] != 1){
            $sql_row[0] = "$subdomain$patron_url$patron_id/checkout";
            $unpurge_worksheet->write_row("A$ucount",\@sql_row);
            $unpurge_total += 1;
            $ucount += 1;
        }

        if($ucount >= $url_limit){
            $ucount = 2;
            $usheet++;
            $unpurge_worksheet = add_worksheet($workbook,\@criteria,"Won't Purge pt. $usheet");        
        }
    }
    
   
    if($purge_total > 0){
        my $totals_worksheet = add_totals_worksheet($workbook,\@criteria);
        my $purge_rate = sprintf("%.0f",100 * ($purge_total)/($purge_total + $unpurge_total));
        my @totals =         (
                $purge_total,
                $unpurge_total,
                $purge_total+$unpurge_total,
                "$purge_rate%",
                $items_checked_out,
                $items_lost,
                $items_claimed,
                sprintf("\$%.2f",$item_fines),
                sprintf("\$%.2f",$lost_fines),
                sprintf("\$%.2f",$total_money_lost));
        $totals_worksheet->write_row("A2",\@totals);        
    }
    create_criteria_worksheet(\@criteria,$workbook);
    $workbook->close(); 
}
# close connection to database       
$dbh->disconnect;
#log completion time   
my $complete_time = (time() - $total_time_start)/60.0;
print("script finished in $complete_time minutes\n");
     
