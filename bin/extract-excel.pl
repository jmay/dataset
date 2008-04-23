#!/usr/bin/env perl

use strict;
use warnings;
use Spreadsheet::ParseExcel;
use Data::Dumper;
use Text::CSV_XS;
use encoding 'utf8';

# my ($file, $skipheaders) = @ARGV;
# my ($file) = @ARGV;

my $excel = Spreadsheet::ParseExcel::Workbook->Parse(\*STDIN);
my $sheets = $excel->{Worksheet};
process_sheet($sheets->[0]); # ignore all but the first page
# foreach my $sheet (@{$excel->{Worksheet}}) {
#   process_sheet($sheet);
# }

sub process_sheet {
  my ($sheet) = @_;

  # printf("Sheet: %s\n", $sheet->{Name});
  $sheet->{MaxRow} ||= $sheet->{MinRow};
  my @rows = ($sheet->{MinRow} .. $sheet->{MaxRow});
  # print scalar(@rows), " rows found.\n";
  # splice(@rows, 0, $skipheaders);
  # print scalar(@rows), " rows left.\n";
  # print Dumper(@rows);

  my $csv = Text::CSV_XS->new;
  for my $row (@rows) {
    my @cells = process_row($sheet, $row);
    # print join(";", @cells), "\n";
    my $status = $csv->combine(@cells);
    # print "*** ", $csv->error_input(), "\n" if !$csv->status;
    print $csv->string(), "\n";
  }
}

sub process_row {
  my ($sheet, $row) = @_;

  my @cells;
  foreach my $col ($sheet->{MinCol} ..  $sheet->{MaxCol}) {
    my $cell = $sheet->{Cells}[$row][$col];
    # if ($cell->{Val} =~ /\*/) {
    #   print $cell->{Type}, " - ", $cell->{Val}, " - ", Dumper($cell->{Format}), "\n";
    # }
    my $val = $cell->{Val};
    # remove non-ascii junk from strings, e.g. em-dashes
    $val =~ s/[[:^print:]]//g if $val;
    push @cells, $val;
  }
  return @cells;
}
