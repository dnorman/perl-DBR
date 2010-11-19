# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Admin::Window::Fields;
use Moose;
extends 'DBR::Admin::Window';

has 'table_id'    => (is => 'ro', required => 1);
has 'table_name' => (is => 'ro', required => 1);
has 'schema_id'   => (is => 'ro', required => 1);
has 'schema_name' => (is => 'ro', required => 1);

sub BUILD {
      my $self = shift;

      my $dbrh = $self->conf_instance->connect or die "Failed to connect";

      my $fields = $dbrh->select( -table => 'dbr_fields',
				  -fields => 'field_id table_id name data_type is_nullable is_signed max_value display_name is_pkey index_type trans_id',
				  -where => { table_id => [ 'd',$self->table_id ] },
				) or throw DBR::Admin::Exception( message => "failed to select from dbr_fields $!",
								  root_window => $self->win->root()
								);
      my %labels = map { $_->{field_id} => $_->{name} } @$fields;

      $self->win->delete('fieldlistbox');
      my $listbox = $self->add( 'fieldlistbox', 'Listbox',
				-y => 2, -width => 25, -vscrollbar => 1,
				-title => "Fields", -border => 1,
				-values => [ sort { lc($labels{$a}) cmp lc($labels{$b}) } keys %labels ],
				-labels => \%labels,
				-onchange => sub {
				      my $fid = $_[0]->get;
				      $self->spawn( 'Field',
						    field_id => $fid,
						    title    =>
						    $self->schema_name . '.' . $self->table_name . '.' . $labels{$fid},
						    dimensions  => '50x15',
						    bordercolor => 'blue'
						  ) }
			      );

      $listbox->draw;
      $listbox->focus;
      $listbox->onBlur(sub{
			     #$self->win->focus('tablelistbox');
			     $self->win->delete('fieldlistbox') && $self->vis_fields(0);
		       });

}





1;
