#!/usr/bin/perl -w

# args:
#   conf   = the config file path
#   confdb = the name of the config file entry to use
#   schema = the handle for the schema to use
#   spec   = path to metadata specification to be imported

# example usage:  load_spec.pl conf=conf/dbr.conf schema=car_dealer spec=conf/meta.txt confdb=dbrconf

# spec file syntax:
#   table name=name singular=name plural=name
#   relation from=table.field to=table.field [ forward=name backward=name ]
#   enums table=name field=name handle=value handle=value [ handle=value ... ]

# TODO:
#   apply field types
#   manage enums and field mappings
#   check that relationship name has no duplicate conflict (or does DBR do this for us?)
#   consider the JSON representation (see conf/meta.json)
#   should insert/update/delete actions be handled by the Config packages?
#   util pkg to gen and merge a json representation; this script bridges spec format only
#     admin tool(s) construct/edit json data and calls same util?

use strict;
use warnings;

use DBR::Util::Logger;
use DBR::Config::MetaSpec;

use Data::Dumper;

use DBR;
use strict;

# params
my %params = %{ &parse_items( \@ARGV ) };
$params{confdb} ||= 'dbrconf';
#print "PARAMS:\n" . Dumper( \%params );

&_usage && exit unless $params{conf} && $params{spec};

# dbr init
my $logger = new DBR::Util::Logger(
                                   -logpath  => '/tmp/dbr_loadspec.log',
                                   -logLevel => 'debug3'
                                  )
  or die "failed to create a DBR::Util::Logger\n";

my $dbr    = new DBR(
		     -logger => $logger,
		     -conf   => $params{conf},
		    )
  or die "failed to create a DBR\n";

my $conf_instance = $dbr->get_instance( $params{confdb} )
  or die "No config entry found with name [$params{confdb}]";

# load spec file
my $spec;
if ($params{spec} =~ m!\.json$!) {
      open( JFILE, "<$params{spec}\n" ) or die "failed to open specified spec file\n";
      my @lines = <JFILE>;
      close JFILE;
      my $json = JSON->new;
      $spec = $json->decode( join( '', @lines ) )
        or die "failed to decode JSON loaded from $params{spec}\n";
      foreach my $schema_spec (@{$spec}) {
            my $schema_handle = $schema_spec->{schema}
              or die "required schema not specified in spec\n";
            next if $params{schema} && $params{schema} ne $schema_handle;
            my $targ_instance = $dbr->get_instance( $schema_handle )
              or die "Failed to get instance for [$schema_handle]\n";
            my $meta = DBR::Config::MetaSpec->new(
                                                  session => $dbr->session,
                                                  conf_instance => $conf_instance,
                                                  targ_instance => $targ_instance,
                                                 )
              or die "failed to create Config::Meta processor\n";
            $meta->process(
                           spec => $schema_spec,
                          )
              or die "failed to process spec\n";
      }
      exit;
}
else {
      $spec = &load_spec( $params{spec} )
        or die "failed to load spec from [$params{spec}]\n";
}
#print "LOADED SPEC:\n" . Dumper( $spec );

my $schema_handle = $params{schema} || $spec->{schema}
  or die "schema must be specified in spec or as command line param\n";

my $scan_instance = $dbr->get_instance( $schema_handle )
  or die "Failed to get instance for [$schema_handle]\n";

my $schema_id = $scan_instance->schema_id
  or die "Failed to get schema_id for $params{scan} instance?!\n";

my $schema = $scan_instance->schema;
die "failed to get schema!\n" unless defined $schema;
die "no schema available?!\n" unless ref( $schema );

my $dbrh = $conf_instance->connect
  or die "failed to get V1 connection to the config metadata database\n";

# get all the ids of the tables in our schema
my $tables = $schema->tables;
my @table_ids = map { $_->{table_id} } @{$tables};

my $relationships = $dbrh->select(
                                  -table => 'dbr_relationships',
                                  -fields => [ qw( relationship_id
                                                   from_name from_table_id from_field_id
                                                   to_name to_table_id to_field_id
                                                   type ) ],
                                  -where  => { from_table_id => [ 'd in', @table_ids ] },
                                 )
  or die "failed to get raw relationship data\n";
#print "EXISTING METADATA DB RELATIONSHIPS:\n" . Dumper( $relationships );

# currently existing relationships $map{t_id}->{f_id} = { info }
# we map all relationships from the table that owns the fkey
my %cur_map = ();
map { $cur_map{$_->{from_table_id}}->{$_->{from_field_id}} = $_ } grep { $_->{type} == 2 } @{$relationships};
map { $cur_map{$_->{to_table_id}}->{$_->{to_field_id}}     = $_ } grep { $_->{type} == 1 } @{$relationships};

# desired relationships
my %new_map = ();
foreach my $relation (@{$spec->{relation}}) {

      # from field
      my ($from_table_name,$from_field_name) = $relation->{from} =~ m!^([^\.]+)\.(.+)$!;
      my $from_table = $schema->get_table( $from_table_name ) or die "$from_table_name not found in schema\n";
      my $from_field = $from_table->get_field( $from_field_name ) or die "$from_table_name.$from_field_name not found\n";

      # target field
      my ($targ_table_name,$targ_field_name) = $relation->{to} =~ m!^([^\.]+)\.(.+)$!;
      my $targ_table = $schema->get_table( $targ_table_name ) or die "$targ_table_name not found in schema\n";
      my $targ_field = $targ_table->get_field( $targ_field_name ) or die "$targ_table_name.$targ_field_name not found\n";

      my %info = (
                  from_table => $from_table,
                  from_field => $from_field,
                  targ_table => $targ_table,
                  targ_field => $targ_field,
                  forward    => $relation->{forward},  # optional
                  backward   => $relation->{backward}, # optional
                 );
      $new_map{$from_table->{table_id}}->{$from_field->field_id} = \%info;
}

# add missing or update existing
foreach my $table_id (keys %new_map) {
      foreach my $field_id (keys %{$new_map{$table_id}}) {
            my $new = $new_map{$table_id}->{$field_id};
            my $from_plural   = $new->{backward}  || $spec->{table}->{$new->{from_table}->name}->{plural}
              or die "missing singular/plural specs for table [" . $new->{from_table}->name . "]\n";
            my $targ_singular = $new->{forward} || $spec->{table}->{$new->{targ_table}->name}->{singular}
              or die "missing singular/plural specs for table [" . $new->{targ_table}->name . "]\n";
            if (exists $cur_map{$table_id}->{$field_id}) {
                  my $curr = $cur_map{$table_id}->{$field_id};
                  if ($curr->{to_table_id} != $new->{targ_table}->{table_id} ||
                      $curr->{to_field_id} != $new->{targ_field}->field_id   ||
                      $curr->{from_name}   ne $from_plural                   ||
                      $curr->{to_name}     ne $targ_singular)
                    {
                          # update - always type=2
                          $dbrh->update(
                                        -table  => 'dbr_relationships',
                                        -fields => {
                                                    from_name   => $from_plural,
                                                    to_name     => $targ_singular,
                                                    to_table_id => [ 'd', $new->{targ_table}->{table_id} ],
                                                    to_field_id => [ 'd', $new->{targ_field}->field_id ],
                                                    type        => [ 'd', 2 ],
                                                   },
                                        -where  => { relationship_id => [ 'd', $curr->{relationship_id} ] },
                                       )
                            or die "failed to update relationship_id=$curr->{relationship_id}\n";

                          print "UPDATED " .
                            $new->{from_table}->name . '.' . $new->{from_field}->name .
                              ": ($curr->{to_name}/$curr->{from_name} to $targ_singular/$from_plural)\n";
                    }
                  else {
                        print "MATCH for " .
                          $new->{from_table}->name . '.' . $new->{from_field}->name .
                            " ($curr->{to_name}/$curr->{from_name})\n";
                  }
            }
            else {
                  # create
                  my $relationship_id = $dbrh->insert(
                                                      -table  => 'dbr_relationships',
                                                      -fields => {
                                                                  from_table_id => [ 'd', $new->{from_table}->{table_id} ],
                                                                  from_field_id => [ 'd', $new->{from_field}->field_id ],
                                                                  from_name     => $from_plural,
                                                                  to_table_id   => [ 'd', $new->{targ_table}->{table_id} ],
                                                                  to_field_id   => [ 'd', $new->{targ_field}->field_id ],
                                                                  to_name       => $targ_singular,
                                                                  type          => [ 'd', 2 ],
                                                                 },
                                                     )
                    or die "create for [$targ_singular/$from_plural] failed\n";

#                  print "INSERTED " .
#                    $new->{from_table}->name . '.' . $new->{from_field}->name .
#                      ": ($targ_singular/$from_plural) relationship id = [$relationship_id]\n";
            }
      }
}
# delete absent
my @delete_ids = ();
foreach my $table_id (keys %cur_map) {
      foreach my $field_id (keys %{$cur_map{$table_id}}) {
            my $curr = $cur_map{$table_id}->{$field_id};
            push @delete_ids, $curr->{relationship_id}
              unless exists $new_map{$table_id}->{$field_id};
      }
}
if (@delete_ids) {
      $dbrh->delete(
                    -table => 'dbr_relationships',
                    -where => { relationship_id => [ 'd in', @delete_ids ] },
                   )
        or die "failed to delete relationships\n";

      print "  deleted.\n";
}

# field types  (NOTE: only blindly sets values for now)
my %trans_map = (
                 enum     => 1,
                 dollars  => 2,
                 unixtime => 3,
                 percent  => 4,
                );
foreach my $table_name (keys %{$spec->{field}}) {
      foreach my $field_name (keys %{$spec->{field}->{$table_name}}) {
            my $type = $spec->{field}->{$table_name}->{$field_name};

            my $table = $schema->get_table( $table_name ) or die "$table_name not found in schema\n";
            my $field = $table->get_field( $field_name ) or die "$table_name.$field_name not found\n";

            $dbrh->update(
                          -table  => 'dbr_fields',
                          -fields => {
                                      trans_id => [ 'd', $trans_map{$type} ],
                                     },
                          -where  => {
                                      field_id => [ 'd', $field->field_id ],
                                     },
                         );
      }
}

# enums
foreach my $table_name (keys %{$spec->{enums}}) {
      foreach my $field_name (keys %{$spec->{enums}->{$table_name}}) {
            # enums is a hashref: handle->description
            my $enums = $spec->{enums}->{$table_name}->{$field_name};
            
      }
}

# quick'n'dirty spec file parser
# returns:
#   {
#     schema => 'handle',
#     table => { name => { singular => 'name', plural => 'name' } },
#     relation => [ { from => 'table.field', to => 'table.field' }, ... ],
#     enums => { table => { field => { handle => 'value' }, { ... }, ... } },
#   }
sub load_spec {
      my $file = shift or die "no spec file!\n";

      # load spec file contents
      open( SFILE, "<$file" ) or die "failed to open spec file [$file]\n";
      chomp( my @lines = <SFILE> );
      close SFILE;

      # capture quoted values
      my @quoted = ();
      my $qindex = 0;
      my $stash = sub { push @quoted, shift; return '{{{' . $qindex++ . '}}}' };

      # populate spec structure
      my %spec = ();
      foreach my $line (@lines) {

            # skip comments and 'blank' lines
            next unless $line =~ m!^\S!;     # has content at the start of the line
            next unless $line =~ m!^[^\#]!;  # not a comment

            # placeholders for quoted values
            $line =~ s!=\'([^\']+)\'!'=' . $stash->($1)!ge;
            $line =~ s!=\"([^\"]+)\"!'=' . $stash->($1)!ge;

            # build hashref from name=value chunks

            # get line items - type is always first word (schema,table,relation,enums)
            my @items = split( /\s+/, $line );
            my $type = shift @items;

            # required context fields as meta info
            my $meta;
            if ($type eq 'enums') {
                  $meta = &parse_items( [ shift @items, shift @items ] );
                  map { $_ =~ s!\{\{\{(\d+)\}\}\}!$quoted[$1]! } values %{$meta};
            } elsif ($type eq 'table') {
                  $meta = &parse_items( [ shift @items ] );
                  map { $_ =~ s!\{\{\{(\d+)\}\}\}!$quoted[$1]! } values %{$meta};
            } elsif ($type eq 'field') {
                  $meta = &parse_items( [ shift @items ] );
                  map { $_ =~ s!\{\{\{(\d+)\}\}\}!$quoted[$1]! } values %{$meta};
            }

            # build hash of remaining name=value pairs
            my $href = &parse_items( \@items );
            map { $_ =~ s!\{\{\{(\d+)\}\}\}!$quoted[$1]! } values %{$href};

            # place hash according to meta info
            if ($type eq 'enums') {
                  $spec{enums}->{$meta->{table}}->{$meta->{field}} = $href;
            }
            elsif ($type eq 'table') {
                  $spec{table}->{$meta->{name}} = $href;
            }
            elsif ($type eq 'field') {
                  $spec{field}->{$meta->{table}} = $href;
            }
            elsif ($type eq 'schema') {
                  $spec{schema} = $href->{name};
            }
            else {
                  push @{$spec{$type} ||= []}, $href;
            }
      }

      return \%spec;
}

# parse command-line args or spec file line items
sub parse_items {
      my $items = shift;
      my $href = shift;

      my %args = ();
      foreach my $item (@{$items}) {
            if (my ($name,$val) = $item =~ m!^([^=]+)=(.+)$!) {
                  $args{$name} = $val;
            }
            else {
                  $args{$item} = 1;
            }
      }
      map { $href->{$_} = $args{$_} } keys %args if $href;
      return $href || \%args;
}

sub _usage {
      print qq~
args:
  conf   = the config file path
  confdb = the name of the config file entry to use (defaults to: dbrconf)
  spec   = path to metadata specification to be imported

example:
  ./load_spec.pl conf=conf/dbr.conf confdb=dbrconf spec=conf/meta.conf

~;
}

1;
