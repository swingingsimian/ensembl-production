=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Bed::BedToBigBed

=head1 DESCRIPTION

Converts a Bed file into a BigBed file ... tadah

Allowed parameters are:

=over 8

=item species - The species to dump

=item base_path - The base of the dumps

=item bed - Path to the bed file we are converting

=item type - The type of bed file we are generating. See code for allowed types

=item bed_to_big_bed - Location of the bedToBigBed binary

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::BedToBigBed;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::Base);
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

sub fetch_input {
  my ($self) = @_;
  $self->SUPER::fetch_input();
  throw "Need a bed file to convert" unless $self->param_is_defined('bed');
  throw "Need to know what type we are converting. We currently allow: ".$self->allowed_types() unless $self->param_is_defined('type');

  $self->assert_executable('bed_to_big_bed', 'bedToBigBed');

  return;
}

sub run {
  my ($self) = @_;
  
  my $bed_to_big_bed = $self->param('bed_to_big_bed');
  my $chrom_sizes = $self->chrom_sizes_file();
  my $bed = $self->param('bed');
  my $big_bed = $bed;
  $big_bed =~ s/\.bed$/.bb/;

  my $type_map = $self->type_to_params();
  my $auto_sql = $self->auto_sql($type_map);
  
  my $extra_index = (defined $type_map->{extra_index} && @{$type_map->{extra_index}}) ? '-extraIndex='.join(q{,}, @{$type_map->{extra_index}}) : q{};
  my $cmd = sprintf('%s -type=%s -as=%s %s %s %s %s', 
    $bed_to_big_bed, $type_map->{type}, $auto_sql, $extra_index, $bed, $chrom_sizes, $big_bed);
  $self->run_cmd($cmd);

  return;
}

sub auto_sql {
  my ($self, $type_map) = @_;
  my $auto_sql_path = $self->generate_file_name('as', $self->param('type'));
  work_with_file($auto_sql_path, 'w', sub {
    my ($fh) = @_;
    print $fh $type_map->{as};
    return;
  });
  return $auto_sql_path;
}

sub allowed_types {
  my ($self) = @_;
  return join(q{, }, keys %{$self->_types_map()});
}

sub type_to_params {
  my ($self) = @_;
  return $self->_types_map()->{$self->param('type')};
}

sub _types_map {
  return {
    bed12 => {
      type => 'bed12',
      extra_index => [qw/name/],
      as => <<AS,
table bed12Source "12 column bed data source"
    (
    string chrom;      "Chromosome (or contig, scaffold, etc.)"
    uint   chromStart; "Start position in chromosome"
    uint   chromEnd;   "End position in chromosome"
    string name;       "Stable ID of the transcript"
    uint   score;      "Score from 0-1000"
    char[1] strand;    "+ or -"
    uint thickStart;   "Start of where display should be thick (start codon)"
    uint thickEnd;     "End of where display should be thick (stop codon)"
    uint reserved;     "Used as itemRgb as of 2004-11-22"
    int blockCount;    "Number of blocks"
    int[blockCount] blockSizes; "Comma separated list of block sizes"
    int[blockCount] chromStarts; "Start positions relative to chromStart"
)
AS
    },
    transcript => {
      type => 'bed12+2',
      extra_index => [qw/name geneStableId display/],
      as => <<AS,
table bed12ext "Ensembl genes with a Gene Symbol and human readable name assigned (name will be stable id)"
    (
    string chrom;      "Chromosome (or contig, scaffold, etc.)"
    uint   chromStart; "Start position in chromosome"
    uint   chromEnd;   "End position in chromosome"
    string name;       "Stable ID of the transcript"
    uint   score;      "Score from 0-1000"
    char[1] strand;    "+ or -"
    uint thickStart;   "Start of where display should be thick (start codon)"
    uint thickEnd;     "End of where display should be thick (stop codon)"
    uint reserved;     "Used as itemRgb as of 2004-11-22"
    int blockCount;    "Number of blocks"
    int[blockCount] blockSizes; "Comma separated list of block sizes"
    int[blockCount] chromStarts; "Start positions relative to chromStart"
    string geneStableId; "Stable ID of the gene"
    string display; "Display label for the gene"
)
AS
    },
    repeat => {
      type => 'bed6',
      as => <<'AS',
table bed6 "Repeats on a genome"
    (
    string chrom;      "Chromosome (or contig, scaffold, etc.)"
    uint   chromStart; "Start position in chromosome"
    uint   chromEnd;   "End position in chromosome"
    string name;       "Stable ID of the transcript"
    uint   score;      "Score from 0-1000"
    char[1] strand;    "+ or -"
)
AS
    },
  };
}

1;
