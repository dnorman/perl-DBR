# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Admin::Window::Field;

use DBR::Config::Field;

use Moose;
extends 'DBR::Admin::Window';

has 'field_id' => (is => 'ro', required => 1);

sub BUILD {
      my $self = shift;
      print STDERR "BUILD Field\n";
      my @readonly_fields = qw(field_id table_id name max_value index_type );

      my $ct = 1;
      my $field = $self->get_field;

      # Booleans
      #foreach my (qw'is_nullable is_signed is_pkey'){

      my $dtlist = DBR::Config::Field->list_datatypes;
      my %dtmap = map { $_->{id} => $_ } @$dtlist;

      my @parts;
      my $datatype = $dtmap{ $field->{data_type} } || {};
      push @parts, $datatype->{handle} . "($field->{max_value})";
      push @parts, $field->{is_signed}   ? 'SIGNED' : 'UNSIGNED';
      push @parts, $field->{is_nullable} ? 'NULL'   : 'NOT_NULL';
      push @parts,'PRIMARY KEY' if $field->{is_pkey};

      $self->add( 'field_basics' . $ct++, 'Label', -y => 1, -x => 1, -text => join(' ', @parts) );
      $self->add("display_name_label",    'Label', -y => 3, -x => 1, -text => "display name: ");

      my $displaybox = $self->add( "display_name", 'TextEntry', -y => 3, -x => 15,-sbborder => 1,
				   -text => $field->{display_name}
				 );


      my $trans = DBR::Config::Trans::list_translators();
      my %labels = map { $_->{id} => $_->{name} } @$trans;
      $labels{ 0 } = " - None - ";
      my @values = sort { lc($labels{$a}) cmp lc($labels{$b}) } keys %labels;
      my ($selected) = grep { $values[$_] == $field->{trans_id} } 0.. $#values;

      $self->add("trans_id_label",             'Label',     -y => 4, -x => 1, -text => "Translator: ");
      my $transbox = $self->add("trans_id_popup", 'Popupmenu', -y => 4, -x => 15 ,
			     -values => \@values,
			     -labels => \%labels,
			     -selected => $selected,
			    );

      $self->add(
		 'submit', 'Buttonbox',
		 -y => 6,-x => 38,
		 -buttons   => [
				{
				 -label => '< Save >',
				 -value => 1,
				 -onpress => sub {
				       $self->save(
						   display_name => $displaybox->get || '',
						   trans_id     => $transbox  ->get || 0,
						  );
				       $self->close;
				 }
				}
			       ]);

      $self->win->draw();
      return 1;


}

sub get_field{
      my $self = shift;

      my $dbrh = $self->conf_instance->connect or die "Failed to connect";
      my $field = $dbrh->select( -table => 'dbr_fields',
				 -fields => 'field_id table_id name data_type is_nullable is_signed max_value display_name is_pkey index_type trans_id',
				 -where => { field_id => ['d',$self->{field_id}] },
				 -single => 1,
				) or die DBR::Admin::Exception->new( message => "failed to select from dbr_fields $!",
								     root_window => $self->win->root()
								   );
      return $field;
}

sub save{
      my $self = shift;
      my %fields = @_;

      return 1 unless %fields;

      my $dbrh = $self->conf_instance->connect or die "Failed to connect";
      my $field = $dbrh->update( -table => 'dbr_fields',
				 -fields => \%fields,
				 -where => { field_id => ['d',$self->{field_id}] },
				) or die DBR::Admin::Exception->new( message => "failed to update dbr_fields $!",
								     root_window => $self->win->root()
								   );
      return 1;
}

1;
