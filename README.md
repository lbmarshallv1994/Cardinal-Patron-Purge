This set of PERL programs facilitates our Patron Purge project. The goal of this project is to identify the patrons that should be deleted from the database based on specifications provided by their staff. The **survey_2_sql** program transforms our patron purge survey into two SQL queries. One of these queries is the "trial" query that will provide data about all of the patrons who will and will not be removed. The second is the purge query that will actually remove the users from the database. The **sql_2_excel** program will run the trial script and provide an excel format spreadsheet that has been formatted to be easily readible.

## Dependencies

This program uses the following PERL dependencies:
* Template
* Parse::CSV
* Data::Dumper
* DateTime  
* Time::Piece
* strict
* warnings
* Template
* DBI
* Net::OpenSSH
* Config::Tiny
* File::Spec
* File::Path
* File::Basename
* Excel::Writer::XLSX
* List::Util
* Data::Dumper

These should all be on CPAN.

## Installation

1. Set up your API connection in **sql_connection.ini** using the provided example file.
    * The [EVERGREEN] section is to set up the links to the patron profiles
2. Set up your **urls.ini**. This will associate each system in the purge form with a subdomain on your Evergreen site. **cardinal_urls.ini** is provided for use with NC Cardinal.
3. Install the dependencies using CPAN.
    ```
    cpan -i Parse::CSV
    ```
## Usage

```
perl survey_2_sql.pl [CSV of your survey results]
```

This will output into a timestamped folder. This folder will contain your trial and purge queries.

```
perl sql_2_excel.pl [mmmm-dd-yy]/scripts/trial
```

This will export your excel spreadsheet.